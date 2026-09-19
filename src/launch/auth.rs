use std::collections::BTreeMap;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use minecraft_msa_auth::MinecraftAuthorizationFlow;
use reqwest::{Client, Response, StatusCode};
use serde::{Deserialize, Serialize};
use tracing::{info, warn};

// BAD: don't use prism's
const DEFAULT_CLIENT_ID: &str = "c36a9fb6-4f2a-41ff-90bd-ae7cc92031eb";
const SCOPE: &str = "XboxLive.signin offline_access";

const DEVICE_CODE_URL: &str = "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode";
const TOKEN_URL: &str = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token";
const PROFILE_URL: &str = "https://api.minecraftservices.com/minecraft/profile";

pub struct Session {
    pub name: String,
    pub uuid: String,
    pub token: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct Stored {
    refresh_token: String,
    minecraft_token: String,
    expires_at: u64,
    name: String,
    uuid: String,
}

type Store = BTreeMap<String, Stored>;

#[derive(Deserialize)]
struct DeviceCode {
    device_code: String,
    user_code: String,
    verification_uri: String,
    expires_in: u64,
    interval: u64,
}

#[derive(Deserialize)]
struct MsToken {
    access_token: String,
    refresh_token: String,
}

#[derive(Deserialize)]
struct Profile {
    id: String,
    name: String,
}

#[derive(Deserialize)]
struct OAuthErrorResponse {
    error: String,

    #[serde(default)]
    error_description: Option<String>,

    #[serde(default)]
    error_codes: Option<Vec<i64>>,

    #[serde(default)]
    correlation_id: Option<String>,

    #[serde(default)]
    trace_id: Option<String>,
}

fn now() -> Result<u64> {
    Ok(SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .context("system clock before unix epoch")?
        .as_secs())
}

fn client_id() -> String {
    std::env::var("MINECRAFT_NIX_CLIENT_ID").unwrap_or_else(|_| DEFAULT_CLIENT_ID.to_string())
}

fn store_path() -> Result<PathBuf> {
    Ok(crate::common::xdg_dir("XDG_DATA_HOME", ".local/share")?
        .join("minecraft-nix")
        .join("accounts.json"))
}

fn load_store() -> Result<Store> {
    match std::fs::read_to_string(store_path()?) {
        Ok(contents) => serde_json::from_str(&contents).context("failed to parse account store"),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(Store::new()),
        Err(err) => Err(err).context("failed to read account store"),
    }
}

fn save_store(store: &Store) -> Result<()> {
    let path = store_path()?;

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    std::fs::write(&path, serde_json::to_string_pretty(store)?)?;

    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600))?;

    Ok(())
}

async fn response_error(resp: Response) -> anyhow::Error {
    let status = resp.status();

    let body = match resp.text().await {
        Ok(body) if !body.is_empty() => body,
        Ok(_) => "<empty response body>".to_string(),
        Err(err) => {
            format!("<failed to read response body: {err}>")
        }
    };

    if let Ok(error) = serde_json::from_str::<OAuthErrorResponse>(&body) {
        let mut message = format!("HTTP {status}: {}", error.error);

        if let Some(description) = error.error_description {
            message.push_str(&format!(": {description}"));
        }

        if let Some(codes) = error.error_codes {
            message.push_str(&format!(" (error_codes: {codes:?})"));
        }

        if let Some(correlation_id) = error.correlation_id {
            message.push_str(&format!(" (correlation_id: {correlation_id})"));
        }

        if let Some(trace_id) = error.trace_id {
            message.push_str(&format!(" (trace_id: {trace_id})"));
        }

        return anyhow::anyhow!(message);
    }

    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&body) {
        let formatted = serde_json::to_string_pretty(&json).unwrap_or_else(|_| body.clone());

        return anyhow::anyhow!("HTTP {status}: {formatted}");
    }

    anyhow::anyhow!("HTTP {status}: {body}")
}

async fn request_device_code(client: &Client, client_id: &str) -> Result<DeviceCode> {
    let resp = client
        .post(DEVICE_CODE_URL)
        .form(&[("client_id", client_id), ("scope", SCOPE)])
        .send()
        .await
        .context("failed to send device code request")?;

    if !resp.status().is_success() {
        return Err(response_error(resp).await).context("device code request failed");
    }

    resp.json()
        .await
        .context("failed to parse device code response")
}

async fn poll_for_token(client: &Client, client_id: &str, device: &DeviceCode) -> Result<MsToken> {
    let mut interval = device.interval;
    let mut elapsed = 0;

    while elapsed < device.expires_in {
        tokio::time::sleep(std::time::Duration::from_secs(interval)).await;

        elapsed += interval;

        let resp = client
            .post(TOKEN_URL)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ("client_id", client_id),
                ("device_code", &device.device_code),
            ])
            .send()
            .await
            .context("failed to send token polling request")?;

        match resp.status() {
            StatusCode::OK => {
                return resp.json().await.context("failed to parse token response");
            }

            StatusCode::BAD_REQUEST => {
                let body = resp
                    .json::<OAuthErrorResponse>()
                    .await
                    .context("failed to parse token error response")?;

                match body.error.as_str() {
                    "authorization_pending" => {
                        continue;
                    }

                    "slow_down" => {
                        interval += 5;
                    }

                    other => {
                        let description = body
                            .error_description
                            .as_deref()
                            .unwrap_or("no error description");

                        anyhow::bail!(
                            "Microsoft authentication failed: \
                             {other}: {description}"
                        );
                    }
                }
            }

            _ => {
                return Err(response_error(resp).await)
                    .context("unexpected response while polling for token");
            }
        }
    }

    anyhow::bail!("device code expired before sign-in completed")
}

async fn refresh(client: &Client, client_id: &str, refresh_token: &str) -> Result<MsToken> {
    let resp = client
        .post(TOKEN_URL)
        .form(&[
            ("grant_type", "refresh_token"),
            ("client_id", client_id),
            ("refresh_token", refresh_token),
            ("scope", SCOPE),
        ])
        .send()
        .await
        .context("failed to send token refresh request")?;

    if !resp.status().is_success() {
        return Err(response_error(resp).await).context("token refresh failed");
    }

    resp.json()
        .await
        .context("failed to parse token refresh response")
}

async fn device_login(client: &Client, client_id: &str) -> Result<MsToken> {
    let device = request_device_code(client, client_id).await?;

    info!(
        "sign in at {} and enter code {}",
        device.verification_uri, device.user_code
    );

    poll_for_token(client, client_id, &device).await
}

async fn fetch_profile(client: &Client, minecraft_token: &str) -> Result<Profile> {
    let resp = client
        .get(PROFILE_URL)
        .bearer_auth(minecraft_token)
        .send()
        .await
        .context("failed to send Minecraft profile request")?;

    if !resp.status().is_success() {
        if resp.status() == StatusCode::NOT_FOUND {
            let error = response_error(resp).await;

            return Err(error).context(
                "Minecraft profile was not found; \
                 this account may not own Minecraft",
            );
        }

        return Err(response_error(resp).await).context("Minecraft profile request failed");
    }

    resp.json()
        .await
        .context("failed to parse Minecraft profile")
}

pub async fn authenticate(account: &str) -> Result<Session> {
    let client = Client::new();
    let client_id = client_id();
    let mut store = load_store()?;

    if let Some(cached) = store.get(account)
        && now()? + 60 < cached.expires_at
    {
        return Ok(Session {
            name: cached.name.clone(),
            uuid: cached.uuid.clone(),
            token: cached.minecraft_token.clone(),
        });
    }

    let ms = match store.get(account) {
        Some(cached) => match refresh(&client, &client_id, &cached.refresh_token).await {
            Ok(token) => token,
            Err(err) => {
                warn!(
                    account = %account,
                    error = %err,
                    "refresh token failed; falling back to device login"
                );

                device_login(&client, &client_id).await?
            }
        },

        None => device_login(&client, &client_id).await?,
    };

    let mc = MinecraftAuthorizationFlow::new(client.clone())
        .exchange_microsoft_token(&ms.access_token)
        .await
        .context("Xbox to Minecraft authentication failed")?;

    let minecraft_token = mc.access_token().as_ref().to_string();

    let profile = fetch_profile(&client, &minecraft_token).await?;

    store.insert(
        account.to_string(),
        Stored {
            refresh_token: ms.refresh_token,
            minecraft_token: minecraft_token.clone(),
            expires_at: now()? + u64::from(mc.expires_in()),
            name: profile.name.clone(),
            uuid: profile.id.clone(),
        },
    );

    save_store(&store)?;

    Ok(Session {
        name: profile.name,
        uuid: profile.id,
        token: minecraft_token,
    })
}

pub fn logout(account: &str) -> Result<()> {
    let mut store = load_store()?;
    store.remove(account);
    save_store(&store)
}

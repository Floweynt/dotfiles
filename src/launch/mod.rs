use std::collections::{BTreeMap, BTreeSet};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::{Context, Result};
use indicatif::{HumanBytes, ProgressBar, ProgressStyle};
use reqwest::Client;
use serde::Deserialize;
use sha1::{Digest, Sha1};
use tracing::{debug, info};

use crate::common::fetch;
use crate::launch::redact::Redactor;
use crate::lock::{self, piston};

pub mod auth;
pub mod redact;

const DOWNLOAD_CONCURRENCY: usize = 64;

pub mod token {
    pub const CACHE_DIR: &str = "@MCN_CACHE_DIR@";
    pub const GAME_DIR: &str = "@MCN_GAME_DIR@";
    pub const ASSETS_DIR: &str = "@MCN_ASSETS_DIR@";
    pub const AUTH_NAME: &str = "@MCN_AUTH_NAME@";
    pub const AUTH_UUID: &str = "@MCN_AUTH_UUID@";
    pub const AUTH_TOKEN: &str = "@MCN_AUTH_TOKEN@";
    pub const AUTH_XUID: &str = "@MCN_AUTH_XUID@";
    pub const AUTH_CLIENTID: &str = "@MCN_AUTH_CLIENTID@";
    pub const AUTH_USER_TYPE: &str = "@MCN_AUTH_USER_TYPE@";
    pub const AUTH_SESSION: &str = "@MCN_AUTH_SESSION@";
}

#[derive(Deserialize)]
pub struct Spec {
    pub steps: Vec<Step>,
    pub launch: LaunchParams,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Step {
    Symlink {
        source: String,
        folder: FolderKind,
        path: String,
        #[serde(default)]
        recursive: bool,
    },
    DownloadAssets {
        descriptor: String,
        index_id: String,
        index_hash: String,
        kind: lock::AssetKind,
    },
}

#[derive(Deserialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
pub enum FolderKind {
    Cache,
    Game,
    Assets,
}

#[derive(Deserialize)]
pub struct LaunchParams {
    pub java: String,
    pub main_class: String,
    pub classpath: Vec<String>,
    pub jvm_args: Vec<String>,
    pub game_args: Vec<String>,
    #[serde(default)]
    pub env: BTreeMap<String, EnvValue>,
    pub game_dir_default: String,
    pub auth: Auth,
}

#[derive(Deserialize)]
#[serde(untagged)]
pub enum EnvValue {
    Plain(String),
    Join {
        join_paths: Vec<String>,
        #[serde(default)]
        inherit_existing: bool,
    },
}

impl EnvValue {
    fn resolve(&self, name: &str) -> String {
        match self {
            EnvValue::Plain(s) => s.clone(),
            EnvValue::Join {
                join_paths,
                inherit_existing,
            } => {
                let mut parts: Vec<String> = join_paths.clone();
                if *inherit_existing
                    && let Ok(existing) = std::env::var(name)
                    && !existing.is_empty()
                {
                    parts.push(existing);
                }
                parts.join(":")
            }
        }
    }
}

#[derive(Deserialize)]
#[serde(tag = "mode", rename_all = "lowercase")]
pub enum Auth {
    Offline {
        username: String,
        uuid: String,
        xuid: String,
    },
    Online {
        account: String,
    },
}

pub struct Credentials {
    pub name: String,
    pub uuid: String,
    pub token: String,
    pub xuid: String,
    pub user_type: String,
    pub clientid: String,
    pub session: String,
}

#[derive(Deserialize)]
struct AssetDescriptor {
    objects: BTreeMap<String, piston::AssetObject>,
}

struct Dirs {
    cache_dir: PathBuf,
    game_dir: PathBuf,
    assets_dir: PathBuf,
}

impl Dirs {
    fn folder(&self, kind: FolderKind) -> &Path {
        match kind {
            FolderKind::Cache => &self.cache_dir,
            FolderKind::Game => &self.game_dir,
            FolderKind::Assets => &self.assets_dir,
        }
    }
}

fn resolve_dirs(spec: &Spec, profile: Option<&str>) -> Result<Dirs> {
    let home = PathBuf::from(std::env::var("HOME").context("HOME is not set")?);
    let cache_dir = crate::common::xdg_dir("XDG_CACHE_HOME", ".cache")?.join("minecraft-nix");

    let mut game_dir = match std::env::var("MINECRAFT_GAME_DIR") {
        Ok(dir) => PathBuf::from(dir),
        Err(_) => match spec.launch.game_dir_default.strip_prefix("$HOME") {
            Some(rest) => PathBuf::from(format!("{}{rest}", home.display())),
            None => PathBuf::from(&spec.launch.game_dir_default),
        },
    };
    if let Some(profile) = profile {
        game_dir.push(profile);
    }

    let assets_dir = match std::env::var("MINECRAFT_ASSETS_DIR") {
        Ok(dir) => PathBuf::from(dir),
        Err(_) => cache_dir.join("assets"),
    };

    for dir in [&game_dir, &assets_dir] {
        std::fs::create_dir_all(dir)
            .with_context(|| format!("failed to create directory {}", dir.display()))?;
    }

    Ok(Dirs {
        cache_dir,
        game_dir,
        assets_dir,
    })
}

fn symlink_tree(src: &Path, dst: &Path) -> Result<()> {
    for entry in std::fs::read_dir(src)
        .with_context(|| format!("failed to read directory {}", src.display()))?
    {
        let entry = entry?;
        let from = entry.path();
        let to = dst.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            std::fs::create_dir_all(&to)?;
            symlink_tree(&from, &to)?;
        } else {
            let _ = std::fs::remove_file(&to);
            std::os::unix::fs::symlink(&from, &to)
                .with_context(|| format!("failed to symlink {}", to.display()))?;
        }
    }
    Ok(())
}

fn sync_symlink(source: &Path, dest: &Path, recursive: bool) -> Result<()> {
    if recursive {
        let marker = dest.join(".ready");
        if marker.exists() {
            return Ok(());
        }
        std::fs::create_dir_all(dest)?;
        symlink_tree(source, dest)?;
        std::fs::write(marker, "")?;
    } else {
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let _ = std::fs::remove_file(dest);
        std::os::unix::fs::symlink(source, dest)
            .with_context(|| format!("failed to symlink {}", dest.display()))?;
    }
    Ok(())
}

fn asset_object_path(assets_dir: &Path, hash: &str) -> PathBuf {
    assets_dir.join("objects").join(&hash[0..2]).join(hash)
}

fn asset_present(assets_dir: &Path, hash: &str, size: u64) -> bool {
    match std::fs::metadata(asset_object_path(assets_dir, hash)) {
        Ok(meta) => meta.len() == size,
        Err(_) => false,
    }
}

fn write_verified(final_path: &Path, bytes: &[u8], hash: &str) -> Result<()> {
    let digest = hex::encode(Sha1::digest(bytes));
    anyhow::ensure!(digest == hash, "checksum mismatch: got {digest}");
    let part_path = final_path.with_extension("part");
    std::fs::write(&part_path, bytes)?;
    std::fs::rename(&part_path, final_path)?;
    Ok(())
}

async fn download_asset(client: &Client, assets_dir: &Path, hash: &str) -> Result<()> {
    let url = format!(
        "https://resources.download.minecraft.net/{}/{hash}",
        &hash[0..2]
    );
    let final_path = asset_object_path(assets_dir, hash);

    fetch::retry(3, || async {
        let bytes = client
            .get(&url)
            .send()
            .await?
            .error_for_status()?
            .bytes()
            .await?;
        let path = final_path.clone();
        let hash = hash.to_string();
        tokio::task::spawn_blocking(move || write_verified(&path, &bytes, &hash))
            .await
            .context("asset write task panicked")?
    })
    .await
    .with_context(|| format!("failed to download asset {hash}"))
}

async fn download_missing(assets_dir: &Path, missing: Vec<(String, u64)>) -> Result<()> {
    let total_bytes: u64 = missing.iter().map(|(_, size)| size).sum();
    info!(
        "downloading {} assets ({})",
        missing.len(),
        HumanBytes(total_bytes)
    );
    let objects_dir = assets_dir.join("objects");
    let prefixes: BTreeSet<&str> = missing.iter().map(|(h, _)| &h[0..2]).collect();
    for prefix in prefixes {
        std::fs::create_dir_all(objects_dir.join(prefix))?;
    }

    let pb = Arc::new(ProgressBar::new(total_bytes));
    pb.set_style(
        ProgressStyle::with_template(
            "{spinner:.green} [{bar:40}] {bytes}/{total_bytes} ({binary_bytes_per_sec}, {eta})",
        )
        .unwrap()
        .progress_chars("=>-"),
    );

    let client = Arc::new(
        Client::builder()
            .pool_max_idle_per_host(DOWNLOAD_CONCURRENCY)
            .build()
            .context("failed to build asset http client")?,
    );
    let semaphore = Arc::new(tokio::sync::Semaphore::new(DOWNLOAD_CONCURRENCY));
    let mut tasks = tokio::task::JoinSet::new();

    for (hash, size) in missing {
        let client = Arc::clone(&client);
        let assets_dir = assets_dir.to_path_buf();
        let semaphore = Arc::clone(&semaphore);
        let pb = Arc::clone(&pb);
        tasks.spawn(async move {
            let _permit = semaphore.acquire_owned().await.unwrap();
            let result = download_asset(&client, &assets_dir, &hash).await;
            if result.is_ok() {
                pb.inc(size);
            }
            result
        });
    }

    let mut first_err = None;
    while let Some(result) = tasks.join_next().await {
        if let Err(err) = result
            .context("asset download task panicked")
            .and_then(|r| r)
            && first_err.is_none()
        {
            first_err = Some(err);
        }
    }

    pb.finish_with_message("assets ready");

    match first_err {
        Some(err) => Err(err),
        None => Ok(()),
    }
}

async fn download_assets(
    assets_dir: &Path,
    descriptor: &str,
    index_id: &str,
    index_hash: &str,
    kind: lock::AssetKind,
) -> Result<()> {
    let indexes_dir = assets_dir.join("indexes");
    std::fs::create_dir_all(&indexes_dir)?;
    let marker = indexes_dir.join(format!("{index_id}.synced"));
    if std::fs::read_to_string(&marker).is_ok_and(|prev| prev.trim() == index_hash) {
        return Ok(());
    }

    let descriptor_contents = std::fs::read_to_string(descriptor)
        .with_context(|| format!("failed to read asset descriptor {descriptor}"))?;
    let descriptor: AssetDescriptor =
        serde_json::from_str(&descriptor_contents).context("failed to parse asset descriptor")?;
    let index_path = indexes_dir.join(format!("{index_id}.json"));
    let index_tmp = indexes_dir.join(format!("{index_id}.json.tmp"));
    std::fs::write(&index_tmp, &descriptor_contents)?;
    std::fs::rename(&index_tmp, &index_path)
        .context("failed to write asset index into assets dir")?;

    let mut unique: BTreeMap<&str, u64> = BTreeMap::new();
    for obj in descriptor.objects.values() {
        unique.insert(&obj.hash, obj.size);
    }

    let missing: Vec<(String, u64)> = unique
        .iter()
        .filter(|(hash, size)| !asset_present(assets_dir, hash, **size))
        .map(|(hash, size)| (hash.to_string(), *size))
        .collect();

    if !missing.is_empty() {
        download_missing(assets_dir, missing).await?;
    }

    if kind != lock::AssetKind::Standard {
        let virtual_dir = assets_dir.join("virtual").join(index_id);
        let objects_root = std::fs::canonicalize(assets_dir)?.join("objects");
        for (name, obj) in &descriptor.objects {
            let link_path = virtual_dir.join(name);
            if let Some(parent) = link_path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            let target = objects_root.join(&obj.hash[0..2]).join(&obj.hash);

            if std::fs::symlink_metadata(&link_path).is_ok() {
                std::fs::remove_file(&link_path)?
            }

            std::os::unix::fs::symlink(&target, &link_path).with_context(|| {
                format!(
                    "failed to symlink {} -> {}",
                    link_path.display(),
                    target.display()
                )
            })?;
        }
    }

    std::fs::write(&marker, index_hash)?;
    Ok(())
}

async fn run_step(step: &Step, dirs: &Dirs) -> Result<()> {
    match step {
        Step::Symlink {
            source,
            folder,
            path,
            recursive,
        } => {
            let dest = dirs.folder(*folder).join(path);
            sync_symlink(Path::new(source), &dest, *recursive)
        }
        Step::DownloadAssets {
            descriptor,
            index_id,
            index_hash,
            kind,
        } => download_assets(&dirs.assets_dir, descriptor, index_id, index_hash, *kind).await,
    }
}

async fn resolve_credentials(auth_spec: &Auth) -> Result<Credentials> {
    match auth_spec {
        Auth::Offline {
            username,
            uuid,
            xuid,
        } => Ok(Credentials {
            name: username.clone(),
            uuid: uuid.clone(),
            token: "0".to_string(),
            xuid: xuid.clone(),
            user_type: "legacy".to_string(),
            clientid: "0".to_string(),
            session: "0".to_string(),
        }),
        Auth::Online { account } => {
            let s = auth::authenticate(account).await?;
            Ok(Credentials {
                session: format!("token:{}:{}", s.token, s.uuid),
                name: s.name,
                uuid: s.uuid,
                token: s.token,
                xuid: String::new(),
                user_type: "msa".to_string(),
                clientid: String::new(),
            })
        }
    }
}

fn substitute(args: &[String], pairs: &[(&str, String)]) -> Vec<String> {
    args.iter()
        .map(|arg| {
            let mut s = arg.clone();
            for (tok, val) in pairs {
                s = s.replace(tok, val);
            }
            s
        })
        .collect()
}

pub async fn run(
    path: PathBuf,
    spec: Spec,
    profile: Option<String>,
    redactor: Redactor,
) -> Result<()> {
    let dirs = resolve_dirs(&spec, profile.as_deref())?;
    let launch = &spec.launch;

    debug!("spec: {}", path.to_string_lossy());
    debug!("java: {}", launch.java);
    debug!("cache dir: {}", dirs.cache_dir.display());
    debug!("game dir: {}", dirs.game_dir.display());
    debug!("assets dir: {}", dirs.assets_dir.display());
    match &launch.auth {
        Auth::Offline { username, .. } => debug!("auth: offline ({username})"),
        Auth::Online { account } => debug!("auth: online (account {account})"),
    }

    for step in &spec.steps {
        run_step(step, &dirs).await?;
    }

    let creds = resolve_credentials(&launch.auth).await?;
    redactor.hide(creds.token.clone());
    redactor.hide(creds.session.clone());

    debug!("player: {} ({})", creds.name, creds.uuid);

    let pairs = [
        (
            token::CACHE_DIR,
            dirs.cache_dir.to_string_lossy().to_string(),
        ),
        (token::GAME_DIR, dirs.game_dir.to_string_lossy().to_string()),
        (
            token::ASSETS_DIR,
            dirs.assets_dir.to_string_lossy().to_string(),
        ),
        (token::AUTH_NAME, creds.name),
        (token::AUTH_UUID, creds.uuid),
        (token::AUTH_TOKEN, creds.token),
        (token::AUTH_XUID, creds.xuid),
        (token::AUTH_CLIENTID, creds.clientid),
        (token::AUTH_USER_TYPE, creds.user_type),
        (token::AUTH_SESSION, creds.session),
    ];

    let mut jvm_args = substitute(&launch.jvm_args, &pairs);
    let classpath = substitute(&launch.classpath, &pairs).join(":");
    jvm_args.push("-cp".to_string());
    jvm_args.push(classpath);
    let game_args = substitute(&launch.game_args, &pairs);

    let env: BTreeMap<&String, String> =
        launch.env.iter().map(|(k, v)| (k, v.resolve(k))).collect();

    for (k, v) in &env {
        debug!("env {k}={v}");
    }
    debug!("exec: {}", launch.java);
    for arg in jvm_args
        .iter()
        .chain(std::iter::once(&launch.main_class))
        .chain(game_args.iter())
    {
        debug!("  {arg}");
    }

    unsafe {
        for (k, v) in &env {
            std::env::set_var(k, v);
        }
    }

    let mut cmd = std::process::Command::new(&launch.java);
    cmd.args(&jvm_args).arg(&launch.main_class).args(&game_args);

    let err = cmd.exec();
    Err(err).context("failed to exec java")
}

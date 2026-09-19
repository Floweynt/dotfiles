use std::future::Future;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result, bail};
use serde::de::DeserializeOwned;
use tokio::sync::Mutex;
use tokio::time::Instant;
use tracing::warn;

const RATE_LIMIT_MAX_WAITS: u32 = 20;
const RATE_LIMIT_BASE: Duration = Duration::from_secs(2);
const RATE_LIMIT_CAP: Duration = Duration::from_secs(60);
const DEFAULT_LIMIT_PER_MIN: u64 = 300;

pub async fn retry<T, F, Fut>(retries: u32, mut attempt: F) -> Result<T>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T>>,
{
    let mut last_err = None;
    for i in 0..retries.max(1) {
        if i > 0 {
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
        match attempt().await {
            Ok(val) => return Ok(val),
            Err(err) => last_err = Some(err),
        }
    }
    Err(last_err.unwrap())
}

fn short_url(url: &str) -> String {
    match url.split_once('?') {
        Some((base, query)) => format!("{base}?…({}b)", query.len()),
        None => url.to_string(),
    }
}

fn header_u64(resp: &reqwest::Response, name: &str) -> Option<u64> {
    resp.headers().get(name)?.to_str().ok()?.trim().parse().ok()
}

fn rate_limit_wait(resp: &reqwest::Response, backoff: Duration) -> Duration {
    match header_u64(resp, "x-ratelimit-reset") {
        Some(s) if s > 0 => Duration::from_secs(s),
        _ => {
            let jitter = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_or(0, |d| u64::from(d.subsec_millis()));
            backoff + Duration::from_millis(jitter)
        }
    }
}

pub struct RateLimiter {
    limit_per_min: AtomicU64,
    slot: Mutex<Instant>,
}

impl RateLimiter {
    pub fn new() -> Self {
        Self {
            limit_per_min: AtomicU64::new(DEFAULT_LIMIT_PER_MIN),
            slot: Mutex::new(Instant::now()),
        }
    }

    async fn throttle(&self) {
        let gap =
            Duration::from_millis(60_000 / self.limit_per_min.load(Ordering::Relaxed).max(1) + 5);
        let target = {
            let mut next = self.slot.lock().await;
            let target = (*next).max(Instant::now());
            *next = target + gap;
            target
        };
        tokio::time::sleep_until(target).await;
    }

    fn observe(&self, resp: &reqwest::Response) {
        if let Some(limit) = header_u64(resp, "x-ratelimit-limit")
            && limit > 0
        {
            self.limit_per_min.store(limit, Ordering::Relaxed);
        }
    }
}

impl Default for RateLimiter {
    fn default() -> Self {
        Self::new()
    }
}

async fn send(
    client: &reqwest::Client,
    url: &str,
    limiter: Option<&RateLimiter>,
) -> Result<reqwest::Response> {
    let mut backoff = RATE_LIMIT_BASE;
    for _ in 0..RATE_LIMIT_MAX_WAITS {
        if let Some(limiter) = limiter {
            limiter.throttle().await;
        }
        let resp = client.get(url).send().await?;
        if resp.status() == reqwest::StatusCode::TOO_MANY_REQUESTS {
            let wait = rate_limit_wait(&resp, backoff);
            warn!(
                "rate limited, waiting {}s: {}",
                wait.as_secs(),
                short_url(url)
            );
            tokio::time::sleep(wait).await;
            backoff = (backoff * 2).min(RATE_LIMIT_CAP);
            continue;
        }
        let resp = resp.error_for_status()?;
        if let Some(limiter) = limiter {
            limiter.observe(&resp);
        }
        return Ok(resp);
    }
    bail!("still rate limited after {RATE_LIMIT_MAX_WAITS} waits");
}

async fn text_inner(
    client: &reqwest::Client,
    url: &str,
    retries: u32,
    limiter: Option<&RateLimiter>,
) -> Result<String> {
    retry(retries, || async {
        let resp = send(client, url, limiter).await?;
        Ok(resp.text().await?)
    })
    .await
    .with_context(|| format!("failed to fetch {}", short_url(url)))
}

pub async fn text(client: &reqwest::Client, url: &str, retries: u32) -> Result<String> {
    text_inner(client, url, retries, None).await
}

pub async fn json<T: DeserializeOwned>(
    client: &reqwest::Client,
    url: &str,
    retries: u32,
) -> Result<T> {
    let body = text_inner(client, url, retries, None).await?;
    serde_json::from_str(&body)
        .with_context(|| format!("failed to parse json from {}", short_url(url)))
}

pub async fn json_paced<T: DeserializeOwned>(
    client: &reqwest::Client,
    url: &str,
    retries: u32,
    limiter: &RateLimiter,
) -> Result<T> {
    let body = text_inner(client, url, retries, Some(limiter)).await?;
    serde_json::from_str(&body)
        .with_context(|| format!("failed to parse json from {}", short_url(url)))
}

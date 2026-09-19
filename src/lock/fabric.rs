use std::sync::Arc;

use anyhow::{Context, Result};
use indicatif::{MultiProgress, ProgressBar};
use regex::Regex;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use tokio::sync::Semaphore;
use tracing::{debug, info, warn};

use crate::common::{fetch, progress, sha1_to_sri};
use crate::lock;

const META: &str = "https://meta.fabricmc.net/v2";
const DEFAULT_MAVEN: &str = "https://maven.fabricmc.net/";
const CONCURRENCY: usize = 24;

fn write_json<T: Serialize>(path: String, value: &T) -> Result<()> {
    std::fs::write(path, serde_json::to_string_pretty(value)?)?;
    Ok(())
}

#[derive(Deserialize)]
struct LoaderListEntry {
    version: String,
    stable: bool,
}

#[derive(Deserialize)]
struct IntermediaryListEntry {
    version: String,
    maven: String,
}

#[derive(Deserialize)]
struct Profile {
    loader: MavenRef,
    #[serde(rename = "launcherMeta")]
    launcher_meta: LauncherMeta,
}

#[derive(Deserialize)]
struct MavenRef {
    maven: String,
}

#[derive(Deserialize)]
struct LauncherMeta {
    #[serde(rename = "mainClass")]
    main_class: MainClass,
    libraries: MetaLibs,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum MainClass {
    Split { client: String },
    Plain(String),
}

#[derive(Deserialize)]
struct MetaLibs {
    #[serde(default)]
    common: Vec<MetaLib>,
    #[serde(default)]
    client: Vec<MetaLib>,
}

#[derive(Deserialize)]
struct MetaLib {
    name: String,
    #[serde(default)]
    url: Option<String>,
    #[serde(default)]
    sha1: Option<String>,
}

#[derive(Serialize)]
struct LoaderLock {
    version: String,
    #[serde(rename = "mainClass")]
    main_class: String,
    libraries: Vec<lock::Library>,
}

#[derive(Serialize)]
struct LoadersManifest {
    latest: String,
    versions: Vec<String>,
}

fn maven_jar_path(coord: &str) -> Result<String> {
    let mut parts = coord.split(':');
    let group = parts.next().context("maven coord missing group")?;
    let artifact = parts.next().context("maven coord missing artifact")?;
    let version = parts.next().context("maven coord missing version")?;
    let classifier = parts.next();
    let group_path = group.replace('.', "/");
    let file = match classifier {
        Some(c) => format!("{artifact}-{version}-{c}.jar"),
        None => format!("{artifact}-{version}.jar"),
    };
    Ok(format!("{group_path}/{artifact}/{version}/{file}"))
}

fn maven_url(base: &str, coord: &str) -> Result<String> {
    let base = base
        .strip_prefix("http://")
        .map_or_else(|| base.to_string(), |rest| format!("https://{rest}"));
    let sep = if base.ends_with('/') { "" } else { "/" };
    Ok(format!("{base}{sep}{}", maven_jar_path(coord)?))
}

async fn resolve_lib(
    client: &Client,
    base: &str,
    coord: &str,
    sha1: Option<&str>,
) -> Result<lock::Library> {
    let url = maven_url(base, coord)?;
    let sha1 = match sha1 {
        Some(s) => s.to_string(),
        None => fetch::text(client, &format!("{url}.sha1"), 3)
            .await?
            .split_whitespace()
            .next()
            .context("empty .sha1 response")?
            .to_string(),
    };
    Ok(lock::Library {
        name: coord.to_string(),
        url,
        hash: sha1_to_sri(&sha1)?,
        native: false,
        os: None,
        arch: None,
        exclude: vec![],
        rules: None,
    })
}

async fn lock_loader(client: &Client, ref_game: &str, loader: &str) -> Result<LoaderLock> {
    let profile: Profile = fetch::json(
        client,
        &format!("{META}/versions/loader/{ref_game}/{loader}"),
        3,
    )
    .await?;

    let main_class = match profile.launcher_meta.main_class {
        MainClass::Split { client } => client,
        MainClass::Plain(s) => s,
    };

    let mut libraries = Vec::new();
    for lib in profile
        .launcher_meta
        .libraries
        .common
        .iter()
        .chain(&profile.launcher_meta.libraries.client)
    {
        let base = lib.url.as_deref().unwrap_or(DEFAULT_MAVEN);
        libraries.push(resolve_lib(client, base, &lib.name, lib.sha1.as_deref()).await?);
    }
    libraries.push(resolve_lib(client, DEFAULT_MAVEN, &profile.loader.maven, None).await?);

    Ok(LoaderLock {
        version: loader.to_string(),
        main_class,
        libraries,
    })
}

fn pick_ref_game(intermediaries: &[IntermediaryListEntry]) -> Result<String> {
    let release = Regex::new(r"^\d+\.\d+(\.\d+)?$").unwrap();
    intermediaries
        .iter()
        .map(|e| &e.version)
        .find(|v| release.is_match(v))
        .cloned()
        .context("no release-shaped intermediary version to use as reference game")
}

async fn run_all<T, F, Fut>(client: Arc<Client>, items: Vec<T>, pb: &ProgressBar, f: F) -> u32
where
    T: Send + 'static,
    F: Fn(Arc<Client>, T) -> Fut,
    Fut: std::future::Future<Output = Result<()>> + Send + 'static,
{
    let semaphore = Arc::new(Semaphore::new(CONCURRENCY));
    let mut tasks = tokio::task::JoinSet::new();
    for item in items {
        let permit = Arc::clone(&semaphore).acquire_owned().await.unwrap();
        let fut = f(Arc::clone(&client), item);
        tasks.spawn(async move {
            let _permit = permit;
            fut.await
        });
    }
    let mut ok = 0;
    while let Some(joined) = tasks.join_next().await {
        pb.inc(1);
        match joined {
            Ok(Ok(())) => ok += 1,
            Ok(Err(err)) => warn!("fabric: {err:#}"),
            Err(err) => warn!("fabric task panicked: {err}"),
        }
    }
    ok
}

pub async fn generate(client: Arc<Client>, out_dir: &str, multi: &MultiProgress) -> Result<()> {
    let loader_dir = format!("{out_dir}/fabric/loader");
    let intermediary_dir = format!("{out_dir}/fabric/intermediary");
    std::fs::create_dir_all(&loader_dir)?;
    std::fs::create_dir_all(&intermediary_dir)?;

    info!("fabric: fetching loader + intermediary lists");
    let loaders: Vec<LoaderListEntry> =
        fetch::json(&client, &format!("{META}/versions/loader"), 3).await?;
    let intermediaries: Vec<IntermediaryListEntry> =
        fetch::json(&client, &format!("{META}/versions/intermediary"), 3).await?;

    let ref_game = pick_ref_game(&intermediaries)?;
    info!(
        "fabric: {} loaders, {} intermediaries, ref game {ref_game}",
        loaders.len(),
        intermediaries.len()
    );

    let latest = loaders
        .iter()
        .find(|l| l.stable)
        .map(|l| l.version.clone())
        .context("no stable fabric loader")?;
    let manifest = LoadersManifest {
        latest,
        versions: loaders.iter().map(|l| l.version.clone()).collect(),
    };
    write_json(format!("{out_dir}/fabric/loaders.json"), &manifest)?;

    let ref_game = Arc::new(ref_game);
    let loader_versions: Vec<String> = loaders.into_iter().map(|l| l.version).collect();
    let loader_pb = progress::bar(multi, loader_versions.len() as u64, "fabric loaders");
    let loaders_ok = run_all(
        Arc::clone(&client),
        loader_versions,
        &loader_pb,
        |client, version| {
            let loader_dir = loader_dir.clone();
            let ref_game = Arc::clone(&ref_game);
            async move {
                let lock = lock_loader(&client, &ref_game, &version)
                    .await
                    .with_context(|| format!("loader {version}"))?;
                write_json(format!("{loader_dir}/{version}.json"), &lock)?;
                debug!("fabric: locked loader {version}");
                Ok(())
            }
        },
    )
    .await;
    loader_pb.finish();

    let intermediary_pb =
        progress::bar(multi, intermediaries.len() as u64, "fabric intermediaries");
    let intermediaries_ok = run_all(client, intermediaries, &intermediary_pb, |client, entry| {
        let intermediary_dir = intermediary_dir.clone();
        async move {
            let version = entry.version.clone();
            let lib = resolve_lib(&client, DEFAULT_MAVEN, &entry.maven, None)
                .await
                .with_context(|| format!("intermediary {version}"))?;
            write_json(format!("{intermediary_dir}/{version}.json"), &lib)?;
            debug!("fabric: locked intermediary {version}");
            Ok(())
        }
    })
    .await;
    intermediary_pb.finish();

    info!("fabric: locked {loaders_ok} loaders, {intermediaries_ok} intermediaries");
    Ok(())
}

use std::{collections::HashMap, sync::Arc};

use anyhow::{Context, Result};
use clap::Parser;
use indicatif::MultiProgress;
use minecraft::common::{fetch, progress};
use minecraft::lock::{self, fabric, mods, piston, transform};
use tokio::sync::{Mutex, Semaphore};
use tracing::{debug, info, warn};

const MANIFEST_URL: &str = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

#[derive(Parser)]
#[command(name = "mc-lock-gen", about = "regenerates mc version metadata")]
struct Cli {
    #[arg(long, default_value = "lock")]
    out: String,
    #[arg(long)]
    skip_vanilla: bool,
    #[arg(long)]
    skip_fabric: bool,
    #[arg(long)]
    skip_mods: bool,
    #[arg(long)]
    mods_limit: Option<usize>,
    #[arg(short, long)]
    verbose: bool,
}

type AssetSeen = Mutex<HashMap<String, (String, lock::AssetKind)>>;

async fn process_version(
    client: &reqwest::Client,
    mv: piston::ManifestVersion,
    versions_dir: &str,
    assets_dir: &str,
    seen_assets: &AssetSeen,
) -> bool {
    let id = mv.id.clone();
    match process_version_inner(client, mv, versions_dir, assets_dir, seen_assets).await {
        Ok(()) => true,
        Err(err) => {
            warn!("skip {id}: {err:#}");
            false
        }
    }
}

async fn resolve_asset_kind(
    client: &reqwest::Client,
    assets_dir: &str,
    index: &piston::AssetIndexRef,
    seen_assets: &AssetSeen,
) -> Result<lock::AssetKind> {
    {
        let seen = seen_assets.lock().await;
        if let Some((sha1, kind)) = seen.get(&index.id) {
            if sha1 != &index.sha1 {
                warn!(
                    "asset index {} seen with different sha1 ({sha1} vs {})",
                    index.id, index.sha1
                );
            }
            return Ok(*kind);
        }
    }

    let idx: piston::AssetIndex = fetch::json(client, &index.url, 3).await?;
    let kind = transform::asset_kind(&idx);

    let objects_json = serde_json::to_string_pretty(&idx.objects)?;
    std::fs::write(format!("{assets_dir}/{}.json", index.id), objects_json)?;

    seen_assets
        .lock()
        .await
        .insert(index.id.clone(), (index.sha1.clone(), kind));

    Ok(kind)
}

async fn process_version_inner(
    client: &reqwest::Client,
    mv: piston::ManifestVersion,
    versions_dir: &str,
    assets_dir: &str,
    seen_assets: &AssetSeen,
) -> Result<()> {
    let meta: piston::VersionMeta = fetch::json(client, &mv.url, 3).await?;
    let kind = resolve_asset_kind(client, assets_dir, &meta.asset_index, seen_assets).await?;

    let id = meta.id.clone();
    let version = transform::version(meta, kind)?;
    let version_json = serde_json::to_string_pretty(&version)?;
    std::fs::write(format!("{versions_dir}/{id}.json"), version_json)?;

    debug!("vanilla: locked {id} ({kind:?} assets)");
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    let default = if cli.verbose {
        "warn,minecraft=debug,mc_lock_gen=debug"
    } else {
        "warn,minecraft=info,mc_lock_gen=info"
    };
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(default));
    let multi = MultiProgress::new();
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .without_time()
        .with_writer(progress::BarWriter(multi.clone()))
        .init();

    let client = Arc::new(reqwest::Client::new());
    std::fs::create_dir_all(&cli.out)?;

    if !cli.skip_vanilla {
        lock_vanilla(&client, &cli.out, &multi).await?;
    }
    if !cli.skip_fabric {
        fabric::generate(Arc::clone(&client), &cli.out, &multi).await?;
    }
    if !cli.skip_mods {
        mods::generate(&client, &cli.out, cli.mods_limit, &multi).await?;
    }

    Ok(())
}

async fn lock_vanilla(
    client: &Arc<reqwest::Client>,
    out: &str,
    multi: &MultiProgress,
) -> Result<()> {
    info!("vanilla: fetching version manifest");
    let manifest_text = fetch::text(client, MANIFEST_URL, 3).await?;
    std::fs::write(format!("{out}/manifest.json"), &manifest_text)?;
    let manifest: piston::Manifest =
        serde_json::from_str(&manifest_text).context("failed to parse manifest")?;

    let versions_dir = format!("{out}/versions");
    let assets_dir = format!("{out}/assets");
    std::fs::create_dir_all(&versions_dir)?;
    std::fs::create_dir_all(&assets_dir)?;

    let total = manifest.versions.len();
    info!("vanilla: locking {total} versions (+ deduped asset indexes)");
    let pb = progress::bar(multi, total as u64, "vanilla versions");

    let semaphore = Arc::new(Semaphore::new(24));
    let seen_assets: Arc<AssetSeen> = Arc::new(Mutex::new(HashMap::new()));

    let mut tasks = tokio::task::JoinSet::new();
    for mv in manifest.versions {
        let client = Arc::clone(client);
        let semaphore = Arc::clone(&semaphore);
        let seen_assets = Arc::clone(&seen_assets);
        let versions_dir = versions_dir.clone();
        let assets_dir = assets_dir.clone();
        tasks.spawn(async move {
            let _permit = semaphore.acquire_owned().await.expect("semaphore closed");
            process_version(&client, mv, &versions_dir, &assets_dir, &seen_assets).await
        });
    }

    let mut ok = 0u32;
    let mut skipped = 0u32;
    while let Some(res) = tasks.join_next().await {
        pb.inc(1);
        if res.context("version task panicked")? {
            ok += 1;
        } else {
            skipped += 1;
        }
    }
    pb.finish();

    info!("vanilla: locked {ok} versions, skipped {skipped}");
    Ok(())
}

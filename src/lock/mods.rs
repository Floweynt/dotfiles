use std::collections::{BTreeMap, BTreeSet, HashMap};

use anyhow::Result;
use indicatif::{MultiProgress, ProgressBar};
use reqwest::Client;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

use crate::common::{fetch, progress, sha512_to_sri};

const API: &str = "https://api.modrinth.com/v2";
const FACETS: &str = r#"[["project_type:mod"],["categories:fabric"],["downloads>=1000"]]"#;
const SEARCH_PAGE: usize = 100;
const BULK_BATCH: usize = 200;

fn write_json<T: Serialize>(path: String, value: &T) -> Result<()> {
    std::fs::write(path, serde_json::to_string_pretty(value)?)?;
    Ok(())
}

#[derive(Deserialize)]
struct SearchResponse {
    total_hits: u64,
    hits: Vec<SearchHit>,
}

#[derive(Deserialize)]
struct SearchHit {
    project_id: String,
}

#[derive(Deserialize)]
struct Project {
    id: String,
    slug: String,
    versions: Vec<String>,
}

#[derive(Deserialize)]
struct Version {
    id: String,
    project_id: String,
    #[serde(default)]
    environment: Option<String>,
    #[serde(default)]
    files: Vec<VersionFile>,
    #[serde(default)]
    dependencies: Vec<Dependency>,
    game_versions: Vec<String>,
    loaders: Vec<String>,
    version_type: String,
    date_published: String,
}

#[derive(Deserialize)]
struct VersionFile {
    url: String,
    filename: String,
    #[serde(default)]
    primary: bool,
    hashes: Hashes,
}

#[derive(Deserialize)]
struct Hashes {
    sha512: String,
}

#[derive(Deserialize)]
struct Dependency {
    project_id: Option<String>,
    dependency_type: String,
}

// One consolidated entry per mod, holding everything the crawl learned about it.
// Keyed by project id (not slug) in the crawl cache: dependencies reference
// project ids, and dedup must happen before a project's slug is known.
struct ModMeta {
    id: String,
    slug: String,
    versions: Vec<Version>,
}

#[derive(Serialize)]
struct ModLock {
    slug: String,
    #[serde(rename = "projectId")]
    project_id: String,
    versions: BTreeMap<String, VersionEntry>,
    #[serde(rename = "byTarget")]
    by_target: BTreeMap<String, Vec<String>>,
}

#[derive(Serialize)]
struct VersionEntry {
    filename: String,
    url: String,
    hash: String,
    #[serde(rename = "gameVersions")]
    game_versions: Vec<String>,
    loaders: Vec<String>,
    #[serde(rename = "versionType")]
    version_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    environment: Option<String>,
    dependencies: Vec<DependencyEntry>,
}

#[derive(Serialize)]
struct DependencyEntry {
    slug: String,
    #[serde(rename = "projectId")]
    project_id: String,
    #[serde(rename = "type")]
    ty: String,
}

async fn search_project_ids(
    client: &Client,
    limit: Option<usize>,
    multi: &MultiProgress,
    limiter: &fetch::RateLimiter,
) -> Result<Vec<String>> {
    let mut ids = Vec::new();
    let mut offset = 0usize;
    let mut pb: Option<ProgressBar> = None;
    loop {
        let url = reqwest::Url::parse_with_params(
            &format!("{API}/search"),
            &[
                ("limit", SEARCH_PAGE.to_string()),
                ("offset", offset.to_string()),
                ("facets", FACETS.to_string()),
            ],
        )?;
        let page: SearchResponse = fetch::json_paced(client, url.as_str(), 3, limiter).await?;
        let total = page.total_hits as usize;
        let pb = pb.get_or_insert_with(|| {
            info!("mods: {total} total hits for facet filter");
            let len = limit.map_or(total, |l| l.min(total));
            progress::bar(multi, len as u64, "modrinth search")
        });
        let got = page.hits.len();
        for hit in page.hits {
            ids.push(hit.project_id);
            if limit.is_some_and(|limit| ids.len() >= limit) {
                pb.set_position(ids.len() as u64);
                pb.finish();
                return Ok(ids);
            }
        }
        pb.set_position(ids.len() as u64);
        offset += SEARCH_PAGE;
        if got == 0 || offset as u64 >= page.total_hits {
            break;
        }
    }
    if let Some(pb) = pb {
        pb.finish();
    }
    Ok(ids)
}

async fn fetch_batched<T: DeserializeOwned>(
    client: &Client,
    endpoint: &str,
    ids: &[String],
    pb: &ProgressBar,
    limiter: &fetch::RateLimiter,
) -> Result<Vec<T>> {
    let chunks = ids.chunks(BULK_BATCH);
    pb.inc_length(chunks.len() as u64);
    let mut out = Vec::new();
    for chunk in chunks {
        let ids_json = serde_json::to_string(chunk)?;
        let url = reqwest::Url::parse_with_params(endpoint, &[("ids", ids_json)])?;
        out.extend(fetch::json_paced::<Vec<T>>(client, url.as_str(), 3, limiter).await?);
        pb.inc(1);
    }
    Ok(out)
}

// Walk the required-dependency closure, fetching each mod at most once. `cache`
// is both the accumulated result and the dedup set.
async fn crawl(
    client: &Client,
    seed: Vec<String>,
    multi: &MultiProgress,
    limiter: &fetch::RateLimiter,
) -> Result<HashMap<String, ModMeta>> {
    let mut cache: HashMap<String, ModMeta> = HashMap::new();
    let pb = progress::bar(multi, 0, "mod metadata");
    let mut frontier = seed;

    while !frontier.is_empty() {
        let to_fetch: Vec<String> = frontier
            .drain(..)
            .filter(|id| !cache.contains_key(id))
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
        if to_fetch.is_empty() {
            continue;
        }
        pb.set_message(format!(
            "mod metadata ({} mods)",
            cache.len() + to_fetch.len()
        ));

        let projects: Vec<Project> =
            fetch_batched(client, &format!("{API}/projects"), &to_fetch, &pb, limiter).await?;
        let version_ids: Vec<String> = projects.iter().flat_map(|p| p.versions.clone()).collect();
        let versions: Vec<Version> = fetch_batched(
            client,
            &format!("{API}/versions"),
            &version_ids,
            &pb,
            limiter,
        )
        .await?;

        let mut by_project: HashMap<String, Vec<Version>> = HashMap::new();
        let mut frontier_next = Vec::new();
        for v in versions {
            for dep in &v.dependencies {
                if dep.dependency_type == "required"
                    && let Some(pid) = &dep.project_id
                    && !cache.contains_key(pid)
                {
                    frontier_next.push(pid.clone());
                }
            }
            by_project.entry(v.project_id.clone()).or_default().push(v);
        }

        for p in projects {
            let versions = by_project.remove(&p.id).unwrap_or_default();
            cache.insert(
                p.id.clone(),
                ModMeta {
                    id: p.id,
                    slug: p.slug,
                    versions,
                },
            );
        }
        frontier = frontier_next;
    }
    pb.finish();
    Ok(cache)
}

fn build_record(meta: &ModMeta, id_to_slug: &HashMap<String, String>) -> ModLock {
    let mut versions: Vec<&Version> = meta.versions.iter().collect();
    versions.sort_by(|a, b| b.date_published.cmp(&a.date_published));

    let mut version_map = BTreeMap::new();
    let mut by_target: BTreeMap<String, Vec<String>> = BTreeMap::new();

    for v in versions {
        let Some(file) = v
            .files
            .iter()
            .find(|f| f.primary)
            .or_else(|| v.files.first())
        else {
            warn!(
                "mods: version {} of {} has no files, skipping",
                v.id, meta.slug
            );
            continue;
        };

        let hash = match sha512_to_sri(&file.hashes.sha512) {
            Ok(h) => h,
            Err(err) => {
                warn!(
                    "mods: bad sha512 for version {} of {}: {err:#}",
                    v.id, meta.slug
                );
                continue;
            }
        };

        let dependencies = v
            .dependencies
            .iter()
            .filter(|d| d.dependency_type == "required")
            .filter_map(|d| {
                let pid = d.project_id.clone()?;
                match id_to_slug.get(&pid) {
                    Some(slug) => Some(DependencyEntry {
                        slug: slug.clone(),
                        project_id: pid,
                        ty: "required".to_string(),
                    }),
                    None => {
                        warn!(
                            "mods: required dep {pid} of version {} ({}) not in closure, skipping",
                            v.id, meta.slug
                        );
                        None
                    }
                }
            })
            .collect();

        version_map.insert(
            v.id.clone(),
            VersionEntry {
                filename: file.filename.clone(),
                url: file.url.clone(),
                hash,
                game_versions: v.game_versions.clone(),
                loaders: v.loaders.clone(),
                version_type: v.version_type.clone(),
                environment: v.environment.clone(),
                dependencies,
            },
        );

        for gv in &v.game_versions {
            for loader in &v.loaders {
                by_target
                    .entry(format!("{gv}+{loader}"))
                    .or_default()
                    .push(v.id.clone());
            }
        }
    }

    ModLock {
        slug: meta.slug.clone(),
        project_id: meta.id.clone(),
        versions: version_map,
        by_target,
    }
}

pub async fn generate(
    client: &Client,
    out_dir: &str,
    limit: Option<usize>,
    multi: &MultiProgress,
) -> Result<()> {
    let mods_dir = format!("{out_dir}/mods/modrinth");
    std::fs::create_dir_all(&mods_dir)?;

    let limiter = fetch::RateLimiter::new();
    let seed = search_project_ids(client, limit, multi, &limiter).await?;
    info!("mods: {} filtered projects", seed.len());

    let cache = crawl(client, seed, multi, &limiter).await?;
    info!("mods: closure has {} mods", cache.len());

    let id_to_slug: HashMap<String, String> = cache
        .values()
        .map(|m| (m.id.clone(), m.slug.clone()))
        .collect();

    let write_pb = progress::bar(multi, cache.len() as u64, "mod records");
    for meta in cache.values() {
        let lock = build_record(meta, &id_to_slug);
        write_json(format!("{mods_dir}/{}.json", meta.slug), &lock)?;
        debug!(
            "mods: wrote {} ({} versions)",
            meta.slug,
            lock.versions.len()
        );
        write_pb.inc(1);
    }
    write_pb.finish();

    info!("mods: wrote {} mod records", cache.len());
    Ok(())
}

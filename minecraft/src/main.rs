use std::{collections::HashMap, time::Duration};

use anyhow::Result;
use base64::{Engine, prelude::BASE64_STANDARD};
use reqwest::get;
use serde::{Deserialize, Serialize};
use serde_json::Deserializer;
use serde_path_to_error::Track;
use std::fmt::Write;
use tokio::{task::JoinSet, time::sleep};

const MANIFEST_URL: &str = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

#[derive(Deserialize, Serialize, Debug)]
struct Latest {
    release: String,
    snapshot: String,
}

#[derive(Deserialize, Serialize, Debug)]
enum ReleaseType {
    #[serde(rename = "release")]
    Release,
    #[serde(rename = "snapshot")]
    Snapshot,
    #[serde(rename = "old_beta")]
    OldBeta,
    #[serde(rename = "old_alpha")]
    OldAlpha,
}

#[derive(Deserialize, Serialize, Debug)]
struct Version {
    id: String,
    #[serde(rename = "type")]
    ty: ReleaseType,
    url: String,
}

#[derive(Deserialize, Serialize, Debug)]
struct Manifest {
    latest: Latest,
    versions: Vec<Version>,
}

#[derive(Deserialize, Serialize, Debug, PartialEq, Eq, Clone, Copy)]
enum ActionType {
    #[serde(rename = "allow")]
    Allow,
    #[serde(rename = "disallow")]
    Disallow,
}

#[derive(Deserialize, Serialize, Debug)]
struct OsRule {
    name: String,
    version: Option<String>,
}

#[derive(Deserialize, Serialize, Debug)]
struct ArchRule {
    arch: String,
}

#[derive(Deserialize, Serialize, Debug)]
struct IsDemoUserFeature {
    is_demo_user: bool,
}

#[derive(Deserialize, Serialize, Debug)]
struct HasCustomResolutionFeature {
    has_custom_resolution: Option<bool>,
}

#[derive(Deserialize, Serialize, Debug)]
struct IsQuickPlaySingleplayerFeature {
    is_quick_play_singleplayer: bool,
}

#[derive(Deserialize, Serialize, Debug)]
struct IsQuickPlayMultiplayerFeature {
    is_quick_play_multiplayer: bool,
}

#[derive(Deserialize, Serialize, Debug)]
struct IsQuickPlayRealmsFeature {
    is_quick_play_realms: bool,
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(untagged)]
enum Rule {
    Os {
        action: ActionType,
        os: OsRule,
    },
    Arch {
        action: ActionType,
        os: ArchRule,
    },
    DemoUserFeature {
        action: ActionType,
        features: IsDemoUserFeature,
    },
    CustomResolutionFeature {
        action: ActionType,
        features: HasCustomResolutionFeature,
    },
    QuickPlaySingleplayerFeature {
        action: ActionType,
        features: IsQuickPlaySingleplayerFeature,
    },
    QuickPlayMultiplayerFeature {
        action: ActionType,
        features: IsQuickPlayMultiplayerFeature,
    },
    QuickPlayRealmsFeature {
        action: ActionType,
        features: IsQuickPlayRealmsFeature,
    },
    Fallback {
        action: ActionType,
    },
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(untagged)]
enum Argument {
    Normal(String),
    ConditionalOne {
        rules: Vec<Rule>,
        value: Vec<String>,
    },
    ConditionalMany {
        rules: Vec<Rule>,
        value: String,
    },
}

#[derive(Deserialize, Serialize, Debug)]
struct Arguments {
    game: Vec<Argument>,
    jvm: Vec<Argument>,
}

#[derive(Deserialize, Serialize, Debug)]
struct Download {
    sha1: String,
    size: usize,
    url: String,
}

#[derive(Deserialize, Serialize, Debug)]
struct Downloads {
    client: Download,
    server: Option<Download>,
    windows_server: Option<Download>,
    client_mappings: Option<Download>,
    server_mappings: Option<Download>,
}

#[derive(Deserialize, Serialize, Debug)]
struct AssetIndex {
    id: String,
    sha1: String,
    size: usize,
    #[serde(rename = "totalSize")]
    total_size: usize,
    url: String,
}

#[derive(Deserialize, Serialize, Debug)]
struct ArtifactDownloads {
    artifact: Download,
}

#[derive(Deserialize, Serialize, Debug)]
struct ArtifactClassifierDownloads {
    classifiers: HashMap<String, Download>,
}

#[derive(Deserialize, Serialize, Debug)]
struct ArtifactNatives {
    linux: Option<String>,
    osx: Option<String>,
    windows: Option<String>,
}

#[derive(Deserialize, Serialize, Debug)]
struct NativeExtract {
    exclude: Vec<String>,
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(untagged)]
enum Artifact {
    Natives {
        downloads: ArtifactClassifierDownloads,
        extract: Option<NativeExtract>,
        name: String,
        natives: ArtifactNatives,
        rules: Option<Vec<Rule>>,
    },
    Downloads {
        downloads: ArtifactDownloads,
        name: String,
        rules: Option<Vec<Rule>>,
    },
}

#[derive(Deserialize, Serialize, Debug)]
struct JavaVersion {
    component: String,
    #[serde(rename = "majorVersion")]
    version: u32,
}

#[derive(Deserialize, Serialize, Debug)]
struct ClientLogging {
    argument: String,
    file: Download,
    #[serde(rename = "type")]
    ty: String,
}

#[derive(Deserialize, Serialize, Debug)]
struct Logging {
    client: ClientLogging,
}

#[derive(Deserialize, Serialize, Debug)]
struct VersionMetadata {
    arguments: Option<Arguments>,
    #[serde(rename = "assetIndex")]
    asset_index: AssetIndex,
    assets: String,
    #[serde(rename = "complianceLevel")]
    compliance_level: Option<i32>,
    downloads: Downloads,
    id: String,
    #[serde(rename = "javaVersion")]
    java_version: Option<JavaVersion>,
    libraries: Vec<Artifact>,
    logging: Option<Logging>,
    #[serde(rename = "mainClass")]
    main_class: String,
    #[serde(rename = "minimumLauncherVersion")]
    minimum_launcher_version: i32,
    #[serde(rename = "releaseTime")]
    release_time: String,
    time: String,
    #[serde(rename = "type")]
    ty: ReleaseType,
    #[serde(rename = "minecraftArguments")]
    minecraft_arguments: Option<String>,
}

async fn fetch_metadata(url: &String) -> Result<String> {
    Ok(get(url).await?.error_for_status()?.text().await?)
}

async fn do_fetch(version: Version) -> Result<VersionMetadata> {
    let result;

    let mut retry = 3;
    loop {
        match fetch_metadata(&version.url).await {
            Ok(x) => {
                result = x;
                break;
            }
            Err(err) => {
                retry -= 1;

                if retry == 0 {
                    return Err(err);
                }

                sleep(Duration::from_secs(1)).await;
            }
        }
    }

    let mut deserializer = Deserializer::from_str(&result);
    let mut track = Track::new();
    let deserializer = serde_path_to_error::Deserializer::new(&mut deserializer, &mut track);

    let data: VersionMetadata = match serde_ignored::deserialize(deserializer, |x| {
        println!("{} {x}", version.url);
    }) {
        Ok(x) => x,
        Err(err) => {
            println!("{}", version.url);
            println!("{}", result);
            println!("{}", track.path());
            return Err(err.into());
        }
    };

    Ok(data)
}

fn format_sha1(data: &str) -> Result<String> {
    Ok(format!(
        "sha1-{}",
        BASE64_STANDARD.encode(hex::decode(data)?)
    ))
}

fn generate_nix_fetch(data: &Download) -> Result<String> {
    Ok(format!(
        "builtins.fetchurl {{ url = {}; hash = {}; }}",
        data.url,
        format_sha1(&data.sha1)?
    ))
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<()> {
    let manifest = get(MANIFEST_URL).await?.error_for_status()?.text().await?;
    let manifest: Manifest = serde_json::from_str(&manifest)?;

    println!("found {} versions", manifest.versions.len());

    let mut set = JoinSet::new();

    for version in manifest.versions {
        set.spawn(do_fetch(version));
    }

    let mut res = vec![];

    while let Some(ent) = set.join_next().await {
        res.push(ent??);
    }

    for version in res {
        let mut buffer = String::new();

        writeln!(buffer, "{{ pkgs, ... }}:")?;
        writeln!(buffer, "let")?;

        let ver = match version.java_version {
            Some(x) => x.version,
            None => 8,
        };

        writeln!(buffer, "java = pkgs.javaPackages.compiler.openjdk{};", ver)?;
        writeln!(buffer, "libraries = {{")?;

        for artifact in version.libraries {
            match artifact {
                Artifact::Natives {
                    downloads,
                    extract,
                    name,
                    natives,
                    rules,
                } => {}

                Artifact::Downloads {
                    downloads,
                    name,
                    rules,
                } => {
                    if let Some(ref rules) = rules {
                        let mut state = ActionType::Disallow;

                        for rule in rules {
                            match rule {
                                Rule::Fallback { action } => state = *action,
                                Rule::Os { action, os } => {
                                    if os.name == "linux" {
                                        state = *action
                                    }
                                }
                                _ => panic!(),
                            }
                        }

                        if state == ActionType::Disallow {
                            println!(
                                "skipping artifact {} for version {} because of rule {:?}",
                                name, version.id, rules
                            );
                            continue;
                        }
                    }

                    writeln!(
                        buffer,
                        r#""{}" = {};"#,
                        name,
                        generate_nix_fetch(&downloads.artifact)?
                    )?;
                }
            }
        }

        writeln!(buffer, "}};")?;
        writeln!(buffer, "in")?;

        println!("{buffer}");
    }

    Ok(())
}

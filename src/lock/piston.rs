use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::common::{ReleaseType, Rule};

#[derive(Deserialize)]
pub struct Manifest {
    pub latest: Latest,
    pub versions: Vec<ManifestVersion>,
}

#[derive(Deserialize)]
pub struct Latest {
    pub release: String,
    pub snapshot: String,
}

#[derive(Deserialize, Clone)]
pub struct ManifestVersion {
    pub id: String,
    #[serde(rename = "type")]
    pub ty: ReleaseType,
    pub url: String,
    pub sha1: String,
}

#[derive(Deserialize)]
pub struct VersionMeta {
    #[serde(default)]
    pub arguments: Option<Arguments>,
    #[serde(rename = "assetIndex")]
    pub asset_index: AssetIndexRef,
    pub downloads: Downloads,
    pub id: String,
    #[serde(rename = "javaVersion", default)]
    pub java_version: Option<JavaVersion>,
    pub libraries: Vec<Library>,
    #[serde(default)]
    pub logging: Option<Logging>,
    #[serde(rename = "mainClass")]
    pub main_class: String,
    #[serde(rename = "minecraftArguments", default)]
    pub minecraft_arguments: Option<String>,
    #[serde(rename = "type")]
    pub ty: ReleaseType,
}

#[derive(Deserialize)]
pub struct Arguments {
    pub game: Vec<Argument>,
    pub jvm: Vec<Argument>,
}

#[derive(Deserialize)]
#[serde(untagged)]
pub enum Argument {
    Plain(String),
    Conditional { rules: Vec<Rule>, value: ArgValue },
}

#[derive(Deserialize)]
#[serde(untagged)]
pub enum ArgValue {
    One(String),
    Many(Vec<String>),
}

#[derive(Deserialize)]
pub struct Downloads {
    pub client: Download,
}

#[derive(Deserialize, Clone)]
pub struct Download {
    pub sha1: String,
    pub size: u64,
    pub url: String,
}

#[derive(Deserialize)]
pub struct AssetIndexRef {
    pub id: String,
    pub sha1: String,
    pub size: u64,
    #[serde(rename = "totalSize")]
    pub total_size: u64,
    pub url: String,
}

#[derive(Deserialize)]
pub struct JavaVersion {
    #[serde(rename = "majorVersion")]
    pub major_version: u32,
}

#[derive(Deserialize)]
pub struct Logging {
    pub client: ClientLogging,
}

#[derive(Deserialize)]
pub struct ClientLogging {
    pub argument: String,
    pub file: Download,
}

#[derive(Deserialize)]
pub struct Library {
    pub name: String,
    #[serde(default)]
    pub downloads: Option<LibraryDownloads>,
    #[serde(default)]
    pub natives: Option<BTreeMap<String, String>>,
    #[serde(default)]
    pub extract: Option<Extract>,
    #[serde(default)]
    pub rules: Option<Vec<Rule>>,
}

#[derive(Deserialize)]
pub struct LibraryDownloads {
    #[serde(default)]
    pub artifact: Option<Download>,
    #[serde(default)]
    pub classifiers: Option<BTreeMap<String, Download>>,
}

#[derive(Deserialize, Clone)]
pub struct Extract {
    pub exclude: Vec<String>,
}

#[derive(Deserialize)]
pub struct AssetIndex {
    pub objects: BTreeMap<String, AssetObject>,
    #[serde(rename = "virtual", default)]
    pub is_virtual: Option<bool>,
    #[serde(default)]
    pub map_to_resources: Option<bool>,
}

#[derive(Deserialize, Serialize, Clone)]
pub struct AssetObject {
    pub hash: String,
    pub size: u64,
}

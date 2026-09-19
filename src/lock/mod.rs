pub mod fabric;
pub mod mods;
pub mod piston;
pub mod transform;

use serde::{Deserialize, Serialize};

use crate::common::{ReleaseType, Rule};

#[derive(Serialize)]
pub struct Version {
    pub id: String,
    #[serde(rename = "type")]
    pub ty: ReleaseType,
    #[serde(rename = "mainClass")]
    pub main_class: String,
    #[serde(rename = "javaMajor", skip_serializing_if = "Option::is_none")]
    pub java_major: Option<u32>,
    pub client: Download,
    pub libraries: Vec<Library>,
    #[serde(rename = "assetIndex")]
    pub asset_index: AssetIndex,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub logging: Option<Logging>,
    pub args: Args,
    #[serde(rename = "minecraftArguments", skip_serializing_if = "Option::is_none")]
    pub minecraft_arguments: Option<String>,
}

#[derive(Serialize)]
pub struct Download {
    pub url: String,
    pub hash: String,
}

#[derive(Serialize)]
pub struct Library {
    pub name: String,
    pub url: String,
    pub hash: String,
    pub native: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub os: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arch: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub exclude: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rules: Option<Vec<Rule>>,
}

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Eq, Debug)]
#[serde(rename_all = "snake_case")]
pub enum AssetKind {
    Standard,
    Virtual,
    MapToResources,
}

#[derive(Serialize)]
pub struct AssetIndex {
    pub id: String,
    pub url: String,
    pub hash: String,
    pub kind: AssetKind,
}

#[derive(Serialize)]
pub struct Logging {
    pub argument: String,
    pub url: String,
    pub hash: String,
}

#[derive(Serialize, Default)]
pub struct Args {
    pub game: Vec<Arg>,
    pub jvm: Vec<Arg>,
}

#[derive(Serialize)]
#[serde(untagged)]
pub enum Arg {
    Plain(String),
    Conditional {
        rules: Vec<Rule>,
        value: Vec<String>,
    },
}

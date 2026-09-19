pub mod fetch;
pub mod progress;

use std::collections::BTreeMap;
use std::path::PathBuf;

use anyhow::{Context, Result};
use base64::{Engine, prelude::BASE64_STANDARD};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseType {
    Release,
    Snapshot,
    OldBeta,
    OldAlpha,
}

#[derive(Deserialize, Serialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    Allow,
    Disallow,
}

#[derive(Deserialize, Serialize, Clone)]
pub struct OsRule {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub arch: Option<String>,
}

#[derive(Deserialize, Serialize, Clone)]
pub struct Rule {
    pub action: Action,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub os: Option<OsRule>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub features: Option<BTreeMap<String, bool>>,
}

pub fn sha1_to_sri(sha1_hex: &str) -> Result<String, hex::FromHexError> {
    Ok(format!(
        "sha1-{}",
        BASE64_STANDARD.encode(hex::decode(sha1_hex)?)
    ))
}

pub fn sha512_to_sri(sha512_hex: &str) -> Result<String, hex::FromHexError> {
    Ok(format!(
        "sha512-{}",
        BASE64_STANDARD.encode(hex::decode(sha512_hex)?)
    ))
}

pub fn xdg_dir(var: &str, home_fallback: &str) -> Result<PathBuf> {
    match std::env::var(var) {
        Ok(dir) => Ok(PathBuf::from(dir)),
        Err(_) => {
            let home = std::env::var("HOME").context("HOME is not set")?;
            Ok(PathBuf::from(home).join(home_fallback))
        }
    }
}

use anyhow::Result;

use crate::common::sha1_to_sri;
use crate::lock::{self, piston};

pub fn asset_kind(index: &piston::AssetIndex) -> lock::AssetKind {
    if index.map_to_resources == Some(true) {
        lock::AssetKind::MapToResources
    } else if index.is_virtual == Some(true) {
        lock::AssetKind::Virtual
    } else {
        lock::AssetKind::Standard
    }
}

pub fn version(meta: piston::VersionMeta, kind: lock::AssetKind) -> Result<lock::Version> {
    let client = lock::Download {
        hash: sha1_to_sri(&meta.downloads.client.sha1)?,
        url: meta.downloads.client.url.clone(),
    };

    let mut libraries = Vec::new();
    for lib in &meta.libraries {
        libraries.extend(library(lib)?);
    }

    let asset_index = lock::AssetIndex {
        id: meta.asset_index.id.clone(),
        url: meta.asset_index.url.clone(),
        hash: sha1_to_sri(&meta.asset_index.sha1)?,
        kind,
    };

    let logging = meta
        .logging
        .map(|l| -> Result<lock::Logging> {
            Ok(lock::Logging {
                hash: sha1_to_sri(&l.client.file.sha1)?,
                url: l.client.file.url,
                argument: l.client.argument,
            })
        })
        .transpose()?;

    let (args, minecraft_arguments) = match meta.arguments {
        Some(arguments) => (convert_arguments(arguments), None),
        None => (lock::Args::default(), meta.minecraft_arguments),
    };

    Ok(lock::Version {
        id: meta.id,
        ty: meta.ty,
        main_class: meta.main_class,
        java_major: meta.java_version.map(|j| j.major_version),
        client,
        libraries,
        asset_index,
        logging,
        args,
        minecraft_arguments,
    })
}

fn make_library(
    lib: &piston::Library,
    dl: &piston::Download,
    native: bool,
    os: Option<String>,
    arch: Option<String>,
    exclude: Vec<String>,
) -> Result<lock::Library> {
    Ok(lock::Library {
        name: lib.name.clone(),
        url: dl.url.clone(),
        hash: sha1_to_sri(&dl.sha1)?,
        native,
        os,
        arch,
        exclude,
        rules: lib.rules.clone(),
    })
}

fn library(lib: &piston::Library) -> Result<Vec<lock::Library>> {
    let Some(downloads) = &lib.downloads else {
        return Ok(vec![]);
    };

    let exclude = lib
        .extract
        .as_ref()
        .map(|e| e.exclude.clone())
        .unwrap_or_else(|| vec!["META-INF/".to_string()]);

    let mut out = Vec::new();

    if let Some(natives) = &lib.natives {
        for (os, template) in natives {
            let variants: Vec<(String, Option<&str>)> = if template.contains("${arch}") {
                vec![
                    (template.replace("${arch}", "32"), Some("x86")),
                    (template.replace("${arch}", "64"), Some("x86_64")),
                ]
            } else {
                vec![(template.clone(), None)]
            };

            for (classifier, arch) in variants {
                let Some(dl) = downloads
                    .classifiers
                    .as_ref()
                    .and_then(|c| c.get(&classifier))
                else {
                    continue;
                };
                out.push(make_library(
                    lib,
                    dl,
                    true,
                    Some(os.clone()),
                    arch.map(str::to_string),
                    exclude.clone(),
                )?);
            }
        }

        if let Some(artifact) = &downloads.artifact {
            out.push(make_library(lib, artifact, false, None, None, vec![])?);
        }
    } else if lib.name.contains(":natives-") {
        let classifier = lib
            .name
            .split(':')
            .nth(3)
            .unwrap_or_default()
            .strip_prefix("natives-")
            .unwrap_or_default();
        let mut parts = classifier.splitn(2, '-');
        let os = match parts.next().unwrap_or_default() {
            "macos" => "osx",
            other => other,
        };
        let arch = match parts.next() {
            Some("arm64") => Some("arm64"),
            Some("x64") | Some("amd64") => Some("x86_64"),
            Some("x86") => Some("x86"),
            _ => None,
        };

        if let Some(artifact) = &downloads.artifact {
            out.push(make_library(
                lib,
                artifact,
                true,
                Some(os.to_string()),
                arch.map(str::to_string),
                exclude,
            )?);
        }
    } else if let Some(artifact) = &downloads.artifact {
        out.push(make_library(lib, artifact, false, None, None, vec![])?);
    }

    Ok(out)
}

fn convert_arguments(args: piston::Arguments) -> lock::Args {
    lock::Args {
        game: args.game.into_iter().map(convert_argument).collect(),
        jvm: args.jvm.into_iter().map(convert_argument).collect(),
    }
}

fn convert_argument(arg: piston::Argument) -> lock::Arg {
    match arg {
        piston::Argument::Plain(s) => lock::Arg::Plain(s),
        piston::Argument::Conditional { rules, value } => lock::Arg::Conditional {
            rules,
            value: match value {
                piston::ArgValue::One(s) => vec![s],
                piston::ArgValue::Many(v) => v,
            },
        },
    }
}

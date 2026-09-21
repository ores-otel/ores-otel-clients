#![forbid(unsafe_code)]

use serde::Deserialize;
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Component, Path, PathBuf};

const MANIFEST_SCHEMA: &str = "ores.otel.polyglot-api-surface/v1";
const MAX_EVIDENCE_BYTES: u64 = 1_048_576;

#[derive(Debug, Deserialize)]
struct SurfaceManifest {
    schema: String,
    authority_repository: String,
    support_matrix: String,
    required_operations: Vec<String>,
    languages: BTreeMap<String, LanguageSurface>,
}

#[derive(Debug, Deserialize)]
struct LanguageSurface {
    operations: BTreeMap<String, OperationEvidence>,
}

#[derive(Debug, Deserialize)]
struct OperationEvidence {
    path: String,
    symbols: Vec<String>,
}

fn repo_root() -> PathBuf {
    let current = std::env::current_dir().expect("read current directory");
    if current.join("governance/api-surface.v1.json").is_file() {
        return current;
    }

    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .expect("clients/rust must live two levels below repository root")
        .to_path_buf()
}

fn safe_relative(path: &str) -> bool {
    let candidate = Path::new(path);
    !candidate.is_absolute()
        && candidate.components().all(|component| {
            !matches!(
                component,
                Component::ParentDir | Component::RootDir | Component::Prefix(_)
            )
        })
}

fn matrix_languages(matrix: &str) -> BTreeSet<String> {
    matrix
        .lines()
        .filter_map(|line| {
            let line = line.trim();
            line.strip_prefix("[languages.")
                .and_then(|rest| rest.strip_suffix(']'))
                .map(str::to_owned)
        })
        .collect()
}

fn verify() -> Result<(), Vec<String>> {
    let root = repo_root();
    let manifest_path = root.join("governance/api-surface.v1.json");
    let manifest_text = fs::read_to_string(&manifest_path)
        .map_err(|error| vec![format!("read {}: {error}", manifest_path.display())])?;
    let manifest: SurfaceManifest = serde_json::from_str(&manifest_text)
        .map_err(|error| vec![format!("parse {}: {error}", manifest_path.display())])?;

    let mut failures = Vec::new();
    if manifest.schema != MANIFEST_SCHEMA {
        failures.push(format!(
            "manifest schema must be {MANIFEST_SCHEMA}, got {}",
            manifest.schema
        ));
    }
    if manifest.authority_repository != "ores-otel/ores-interfaces" {
        failures.push("authority_repository must remain ores-otel/ores-interfaces".to_owned());
    }
    if manifest.required_operations.is_empty() {
        failures.push("required_operations must not be empty".to_owned());
    }
    if !safe_relative(&manifest.support_matrix) {
        failures.push("support_matrix must be a safe repository-relative path".to_owned());
    }

    let matrix_path = root.join(&manifest.support_matrix);
    let matrix_text = match fs::read_to_string(&matrix_path) {
        Ok(value) => value,
        Err(error) => {
            failures.push(format!("read {}: {error}", matrix_path.display()));
            String::new()
        }
    };

    let matrix = matrix_languages(&matrix_text);
    let governed: BTreeSet<String> = manifest.languages.keys().cloned().collect();
    for missing in matrix.difference(&governed) {
        failures.push(format!(
            "support-matrix language {missing} has no governed API-surface entry"
        ));
    }
    for extra in governed.difference(&matrix) {
        failures.push(format!(
            "governance language {extra} is absent from clients/support-matrix.toml"
        ));
    }

    let mut evidence_count = 0usize;
    for (language, surface) in &manifest.languages {
        for operation in &manifest.required_operations {
            let Some(evidence) = surface.operations.get(operation) else {
                failures.push(format!(
                    "{language} does not declare evidence for required operation {operation}"
                ));
                continue;
            };
            if !safe_relative(&evidence.path) {
                failures.push(format!(
                    "{language}/{operation} evidence path is not repository-relative: {}",
                    evidence.path
                ));
                continue;
            }
            if evidence.symbols.is_empty() || evidence.symbols.iter().any(|symbol| symbol.is_empty()) {
                failures.push(format!(
                    "{language}/{operation} must declare non-empty surface symbols"
                ));
                continue;
            }

            let path = root.join(&evidence.path);
            let metadata = match fs::symlink_metadata(&path) {
                Ok(value) => value,
                Err(error) => {
                    failures.push(format!("read metadata {}: {error}", path.display()));
                    continue;
                }
            };
            if metadata.file_type().is_symlink() || !metadata.is_file() {
                failures.push(format!(
                    "{language}/{operation} evidence must be a regular file: {}",
                    evidence.path
                ));
                continue;
            }
            if metadata.len() > MAX_EVIDENCE_BYTES {
                failures.push(format!(
                    "{language}/{operation} evidence exceeds {MAX_EVIDENCE_BYTES} bytes: {}",
                    evidence.path
                ));
                continue;
            }

            let source = match fs::read_to_string(&path) {
                Ok(value) => value,
                Err(error) => {
                    failures.push(format!("read {}: {error}", path.display()));
                    continue;
                }
            };
            for symbol in &evidence.symbols {
                if !source.contains(symbol) {
                    failures.push(format!(
                        "{language}/{operation} is missing governed surface token {symbol:?} in {}",
                        evidence.path
                    ));
                }
            }
            evidence_count += 1;
        }
    }

    if failures.is_empty() {
        println!(
            "polyglot API surface: PASS ({} languages, {} required operations, {} evidence bindings)",
            manifest.languages.len(),
            manifest.required_operations.len(),
            evidence_count
        );
        Ok(())
    } else {
        Err(failures)
    }
}

fn main() {
    if let Err(failures) = verify() {
        eprintln!("polyglot API surface: FAIL");
        for failure in failures {
            eprintln!("- {failure}");
        }
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::{matrix_languages, safe_relative};

    #[test]
    fn rejects_paths_that_escape_the_repository() {
        assert!(!safe_relative("../outside"));
        assert!(!safe_relative("/absolute"));
        assert!(safe_relative("clients/rust/src/client.rs"));
    }

    #[test]
    fn extracts_declared_language_sections_only() {
        let matrix = "[capabilities]\nrequired_operations = [\"health\"]\n[languages.rust]\ntier = 1\n[languages.dart]\ntier = 1\n";
        let languages = matrix_languages(matrix);
        assert_eq!(languages.into_iter().collect::<Vec<_>>(), vec!["dart", "rust"]);
    }
}

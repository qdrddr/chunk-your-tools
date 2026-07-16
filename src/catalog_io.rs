use crate::build::CatalogIndex;
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

/// Resolve output directory and prune flag from optional overrides and path config.
pub fn resolve_write_catalog_paths(
    output_dir: Option<&Path>,
    prune: Option<bool>,
) -> (PathBuf, bool) {
    let cfg = crate::paths::snapshot();
    let dir = output_dir
        .map(Path::to_path_buf)
        .unwrap_or(cfg.default_catalog_dir);
    let prune = prune.unwrap_or(cfg.write_catalog_prune);
    (dir, prune)
}

/// Write catalog index using optional output dir / prune (defaults from [`crate::paths`]).
///
/// # Errors
/// Returns an error string when the output directory cannot be created or catalog files cannot be written.
pub fn write_catalog_index_resolved(
    index: &CatalogIndex,
    output_dir: Option<&Path>,
    prune: Option<bool>,
) -> Result<(), String> {
    let (dir, prune) = resolve_write_catalog_paths(output_dir, prune);
    write_catalog_index(index, &dir, prune)
}

/// Write catalog index files under `output_dir`, optionally pruning stale entries.
///
/// # Errors
/// Returns an error string when the output directory cannot be created, files cannot be written, or pruning fails.
pub fn write_catalog_index(
    index: &CatalogIndex,
    output_dir: &Path,
    prune: bool,
) -> Result<(), String> {
    let root = output_dir;
    fs::create_dir_all(root).map_err(|e| e.to_string())?;
    let schemas = root.join("schemas");
    fs::create_dir_all(&schemas).map_err(|e| e.to_string())?;

    let mut output_map: HashMap<PathBuf, String> = HashMap::new();
    for (rel_path, content) in &index.files {
        output_map.insert(root.join(rel_path), content.clone());
    }

    apply_outputs(&output_map)?;
    if prune {
        let expected: HashSet<PathBuf> = output_map.keys().cloned().collect();
        prune_stale_files(root, &expected)?;
    }
    Ok(())
}

fn apply_outputs(output_map: &HashMap<PathBuf, String>) -> Result<(), String> {
    for (path, content) in output_map {
        if path.exists()
            && let Ok(existing) = fs::read_to_string(path)
            && existing == *content
        {
            continue;
        }
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        fs::write(path, content).map_err(|e| e.to_string())?;
    }
    Ok(())
}

fn should_skip_hidden(path: &Path, root: &Path) -> bool {
    path.strip_prefix(root).ok().is_some_and(|rel| {
        rel.components()
            .any(|c| c.as_os_str().to_string_lossy().starts_with('.'))
    })
}

fn prune_stale_files(root: &Path, expected_paths: &HashSet<PathBuf>) -> Result<(), String> {
    if !root.exists() {
        return Ok(());
    }

    let mut all_paths: Vec<PathBuf> = Vec::new();
    collect_paths(root, &mut all_paths)?;

    for path in &all_paths {
        if should_skip_hidden(path, root) {
            continue;
        }
        if path.is_file() && !expected_paths.contains(path) {
            fs::remove_file(path).map_err(|e| e.to_string())?;
        }
    }

    all_paths.sort_by_key(|p| std::cmp::Reverse(p.components().count()));
    for path in all_paths {
        if should_skip_hidden(&path, root) {
            continue;
        }
        if path.is_dir() && path.read_dir().is_ok_and(|mut d| d.next().is_none()) {
            let _ = fs::remove_dir(path);
        }
    }
    Ok(())
}

fn collect_paths(dir: &Path, out: &mut Vec<PathBuf>) -> Result<(), String> {
    if !dir.is_dir() {
        return Ok(());
    }
    for entry in fs::read_dir(dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        out.push(path.clone());
        if path.is_dir() {
            collect_paths(&path, out)?;
        }
    }
    Ok(())
}

fn catalog_rel_path(root: &Path, path: &Path) -> Result<String, String> {
    Ok(path
        .strip_prefix(root)
        .map_err(|e| e.to_string())?
        .to_string_lossy()
        .replace('\\', "/"))
}

fn load_tools_from_catalog_file(path: &Path) -> Result<Vec<Value>, String> {
    let raw = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let val: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    val.as_array()
        .cloned()
        .or_else(|| val.get("tools").and_then(Value::as_array).cloned())
        .ok_or_else(|| format!("{} must contain a tools array", path.display()))
}

fn collect_catalog_files(
    root: &Path,
    dir: &Path,
    files: &mut HashMap<String, String>,
) -> Result<(), String> {
    for entry in fs::read_dir(dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if path.is_dir() {
            collect_catalog_files(root, &path, files)?;
            continue;
        }
        if !path.is_file() {
            continue;
        }
        let rel_str = catalog_rel_path(root, &path)?;
        let content = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        files.insert(rel_str, content);
    }
    Ok(())
}

/// Load a catalog index written by [`write_catalog_index`] or the `decompose` CLI.
///
/// Reads `tools.json` into [`CatalogIndex::tools`] and every other file under the
/// catalog root into [`CatalogIndex::files`].
///
/// # Errors
/// Returns an error when the directory is missing, unreadable, or `tools.json` is invalid.
pub fn load_catalog_index_from_dir(dir: &Path) -> Result<CatalogIndex, String> {
    if !dir.is_dir() {
        return Err(format!("Catalog directory not found: {}", dir.display()));
    }

    let tools_path = dir.join("tools.json");
    let tools = if tools_path.is_file() {
        load_tools_from_catalog_file(&tools_path)?
    } else {
        Vec::new()
    };

    let mut files = HashMap::new();
    collect_catalog_files(dir, dir, &mut files)?;

    Ok(CatalogIndex { tools, files })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::build::build_catalog_index;
    use serde_json::json;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_catalog_dir() -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |duration| duration.as_nanos());
        std::env::temp_dir().join(format!("chunk-your-tools-catalog-{nanos}"))
    }

    #[test]
    fn load_catalog_index_from_dir_round_trip() -> Result<(), String> {
        let dir = temp_catalog_dir();
        let tools = [json!({
            "id": "Agent",
            "full_schema": {
                "id": "Agent",
                "name": "Agent",
                "inputSchema": {
                    "type": "object",
                    "properties": {"prompt": {"type": "string"}},
                    "required": ["prompt"]
                }
            }
        })];
        let index = build_catalog_index(&tools, &[]);
        write_catalog_index(&index, &dir, false)?;
        let loaded = load_catalog_index_from_dir(&dir)?;
        assert_eq!(loaded.tools.len(), index.tools.len());
        assert!(loaded.files.contains_key("schemas/decomposed/Agent.json"));
        assert!(
            loaded
                .files
                .contains_key("schemas/decomposed/metadata.json")
        );
        let _ = fs::remove_dir_all(&dir);
        Ok(())
    }
}

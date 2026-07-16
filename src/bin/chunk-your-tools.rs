#![allow(clippy::multiple_crate_versions)]

use chunk_your_tools::{
    CatalogIndex, DecomposedCatalog, NamedSurvivors, PolicyContext, RetrieveOptions,
    build_catalog_from_tools, build_process_groups_options, load_catalog_index_from_dir,
    parse_tool_kind, parse_tool_policy, parse_tool_policy_pair, per_tool_policies_from_value,
    policy_context_from_values, recompose_tools_from_index, retrieve_tools_from_catalog,
};
use clap::{ArgGroup, Parser, Subcommand};
use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Parser)]
#[command(name = "chunk-your-tools")]
#[command(about = "Chunk/Decompose and recompose MCP tool definition schemas")]
#[command(version = env!("CARGO_PKG_VERSION"))]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Decompose MCP tools JSON into a catalog directory
    Decompose {
        #[arg(long)]
        input: PathBuf,
        #[arg(long)]
        output: PathBuf,
    },
    /// Recompose pruned tools from survivors and a tools JSON or on-disk catalog
    #[command(group(
        ArgGroup::new("source")
            .required(true)
            .args(["input", "catalog_dir"])
    ))]
    Recompose {
        /// Full tools JSON (catalog built in memory)
        #[arg(long, group = "source")]
        input: Option<PathBuf>,
        /// Pre-decomposed catalog directory (from `decompose`)
        #[arg(long, group = "source")]
        catalog_dir: Option<PathBuf>,
        #[arg(long)]
        survivors: PathBuf,
        #[arg(long)]
        output: PathBuf,
        #[arg(long)]
        config: Option<PathBuf>,
        #[arg(long)]
        system_policy: Option<String>,
        #[arg(long)]
        mcp_policy: Option<String>,
        /// Treat every tool as system or mcp (overrides `mcp__` prefix detection)
        #[arg(long, value_name = "system|mcp")]
        tool_type: Option<String>,
        #[arg(long)]
        per_tool: Option<PathBuf>,
        #[arg(long = "tool-policy", value_name = "TOOL=POLICY")]
        tool_policies: Vec<String>,
    },
}

fn load_tools_array(tools: &Path) -> Result<Vec<Value>, Box<dyn std::error::Error>> {
    let raw = fs::read_to_string(tools)?;
    let tools_val: Value = serde_json::from_str(&raw)?;
    tools_val
        .as_array()
        .cloned()
        .or_else(|| tools_val.get("tools").and_then(|v| v.as_array()).cloned())
        .ok_or_else(|| "Expected tools array in input JSON".into())
}

fn load_catalog_index(
    input: Option<&Path>,
    catalog_dir: Option<&Path>,
) -> Result<CatalogIndex, Box<dyn std::error::Error>> {
    match (input, catalog_dir) {
        (Some(path), None) => Ok(build_catalog_from_tools(&load_tools_array(path)?)),
        (None, Some(dir)) => Ok(load_catalog_index_from_dir(dir)?),
        _ => Err("Provide exactly one of --input or --catalog-dir".into()),
    }
}

fn policy_context_from_cli(
    config: Option<&Path>,
    system_policy: Option<&str>,
    mcp_policy: Option<&str>,
    tool_type: Option<&str>,
    per_tool: Option<&Path>,
    tool_policies: &[String],
) -> Result<PolicyContext, Box<dyn std::error::Error>> {
    let mut ctx = match config {
        Some(path) => {
            let raw = fs::read_to_string(path)?;
            policy_context_from_values(&serde_json::from_str(&raw)?)
        }
        None => PolicyContext::new(),
    };

    if let Some(s) = system_policy {
        ctx.system_policy =
            parse_tool_policy(s).ok_or_else(|| format!("invalid system policy: {s}"))?;
    }
    if let Some(m) = mcp_policy {
        ctx.mcp_policy = parse_tool_policy(m).ok_or_else(|| format!("invalid mcp policy: {m}"))?;
    }
    if let Some(kind) = tool_type {
        ctx.tool_kind_override = Some(
            parse_tool_kind(kind)
                .ok_or_else(|| format!("invalid tool type: {kind} (expected system or mcp)"))?,
        );
    }

    if let Some(path) = per_tool {
        let raw = fs::read_to_string(path)?;
        let val: Value = serde_json::from_str(&raw)?;
        chunk_your_tools::apply_per_tool_overrides(&mut ctx, per_tool_policies_from_value(&val)?);
    }

    let mut cli_overrides = HashMap::new();
    for spec in tool_policies {
        let (tool_id, policy) = parse_tool_policy_pair(spec)?;
        cli_overrides.insert(tool_id, policy);
    }
    chunk_your_tools::apply_per_tool_overrides(&mut ctx, cli_overrides);

    Ok(ctx)
}

fn run_decompose(input: &Path, output: &Path) -> Result<(), Box<dyn std::error::Error>> {
    let tools_arr = load_tools_array(input)?;
    let index = build_catalog_from_tools(&tools_arr);
    fs::create_dir_all(output)?;
    for (rel, content) in &index.files {
        let path = output.join(rel);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(path, content)?;
    }
    eprintln!("Wrote {} files to {}", index.files.len(), output.display());
    Ok(())
}

fn recompose_tools(
    index: &CatalogIndex,
    survivors_val: &Value,
    ctx: &PolicyContext,
) -> Result<Vec<Value>, Box<dyn std::error::Error>> {
    if survivors_val.get("tools").is_some() {
        let survivors = NamedSurvivors::from_value(survivors_val)?;
        return Ok(recompose_tools_from_index(index, &survivors, ctx));
    }
    if survivors_val.get("json").is_some() || survivors_val.get("md").is_some() {
        let build_catalog = index.to_catalog_dict();
        let mut store = DecomposedCatalog::from_catalog_index(index);
        let process_groups = build_process_groups_options(ctx, &build_catalog, &store, None);
        let opts = RetrieveOptions {
            apply_decomposed_score_filter: false,
            process_groups,
        };
        return Ok(retrieve_tools_from_catalog(
            ctx,
            survivors_val,
            &build_catalog,
            &mut store,
            &opts,
        ));
    }
    Err(
        "survivors JSON must include \"tools\" (semantic names) or \"json\"/\"md\" (legacy chunks)"
            .into(),
    )
}

#[allow(clippy::too_many_arguments)]
fn run_recompose(
    input: Option<&Path>,
    catalog_dir: Option<&Path>,
    survivors_path: &Path,
    output: &Path,
    config: Option<&Path>,
    system_policy: Option<&str>,
    mcp_policy: Option<&str>,
    tool_type: Option<&str>,
    per_tool: Option<&Path>,
    tool_policies: &[String],
) -> Result<(), Box<dyn std::error::Error>> {
    let ctx = policy_context_from_cli(
        config,
        system_policy,
        mcp_policy,
        tool_type,
        per_tool,
        tool_policies,
    )?;
    let index = load_catalog_index(input, catalog_dir)?;
    let survivors_raw = fs::read_to_string(survivors_path)?;
    let survivors_val: Value = serde_json::from_str(&survivors_raw)?;
    let tools = recompose_tools(&index, &survivors_val, &ctx)?;
    let mut json = serde_json::to_string_pretty(&tools)?;
    json.push('\n');
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(output, json)?;
    eprintln!("Wrote {} tools to {}", tools.len(), output.display());
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Decompose { input, output } => run_decompose(&input, &output)?,
        Commands::Recompose {
            input,
            catalog_dir,
            survivors,
            output,
            config,
            system_policy,
            mcp_policy,
            tool_type,
            per_tool,
            tool_policies,
        } => run_recompose(
            input.as_deref(),
            catalog_dir.as_deref(),
            &survivors,
            &output,
            config.as_deref(),
            system_policy.as_deref(),
            mcp_policy.as_deref(),
            tool_type.as_deref(),
            per_tool.as_deref(),
            &tool_policies,
        )?,
    }
    Ok(())
}

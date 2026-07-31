import {
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildCatalogIndex } from "chunk-your-tools";

/** @typedef {Record<string, unknown>} JsonRecord */
/** @typedef {{ content?: unknown; file_path?: string; id?: string }} CatalogEntry */
/** @typedef {{ json?: CatalogEntry[]; md?: CatalogEntry[]; tools?: JsonRecord[] }} SnapshotStage */
/** @typedef {{ pruning?: { decomposed_catalog?: Record<string, SnapshotStage> }; body?: { tools?: JsonRecord[] }; tools?: JsonRecord[] }} SnapshotData */

const REPO_ROOT = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
  "..",
);

const SKIP_SNAPSHOT_DIRS = new Set([
  ".git",
  ".fallow",
  "node_modules",
  "target",
]);

/** @returns {Set<string>} */
function buildAllowedSnapshotPaths() {
  /** @type {Set<string>} */
  const allowed = new Set();

  /** @param {string} dir @param {string} rel */
  const walk = (dir, rel) => {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (SKIP_SNAPSHOT_DIRS.has(entry.name)) {
        continue;
      }
      const childRel = rel ? `${rel}/${entry.name}` : entry.name;
      const childAbs = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(childAbs, childRel);
        continue;
      }
      if (!entry.name.endsWith(".json")) {
        continue;
      }
      allowed.add(childRel);
      allowed.add(entry.name);
    }
  };

  walk(REPO_ROOT, "");
  return allowed;
}

const ALLOWED_SNAPSHOT_PATHS = buildAllowedSnapshotPaths();

/**
 * @param {string} userPath
 * @returns {string}
 */
function resolveAllowedSnapshotPath(userPath) {
  const snapshotName = basename(userPath.replaceAll("\\", "/"));
  if (!ALLOWED_SNAPSHOT_PATHS.has(snapshotName)) {
    throw new Error(
      `snapshot file is not an allowed repo JSON path: ${userPath}`,
    );
  }
  let snapshotRel = snapshotName;
  for (const entry of ALLOWED_SNAPSHOT_PATHS) {
    if (entry === snapshotName || entry.endsWith(`/${snapshotName}`)) {
      snapshotRel = entry;
      break;
    }
  }
  return join(REPO_ROOT, ...snapshotRel.split("/"));
}

/** @returns {{ file: string | null; output: string | null }} */
function readEnvArgs() {
  return {
    file:
      process.env.CHUNK_YOUR_TOOLS_E2E_FILE ??
      process.env.npm_config_file ??
      null,
    output:
      process.env.CHUNK_YOUR_TOOLS_E2E_OUTPUT ??
      process.env.npm_config_output ??
      null,
  };
}

/**
 * @param {string[]} argv
 * @param {number} index
 * @param {string} flag
 * @returns {{ value: string | null; nextIndex: number } | null}
 */
function readArgvFlag(argv, index, flag) {
  const arg = argv[index];
  const prefix = `${flag}=`;
  if (arg === flag) {
    return { value: argv[index + 1] ?? null, nextIndex: index + 1 };
  }
  if (arg.startsWith(prefix)) {
    return { value: arg.slice(prefix.length), nextIndex: index };
  }
  return null;
}

/**
 * @param {string[] | undefined} [argv]
 * @returns {{ file: string | null; output: string | null }}
 */
function readTestArgs(argv = process.argv) {
  const envArgs = readEnvArgs();
  if (envArgs.file || envArgs.output) {
    return envArgs;
  }

  /** @type {string | null} */
  let file = null;
  /** @type {string | null} */
  let output = null;

  for (let i = 0; i < argv.length; i += 1) {
    const fileFlag = readArgvFlag(argv, i, "--file");
    if (fileFlag) {
      file = fileFlag.value;
      i = fileFlag.nextIndex;
      continue;
    }
    const outputFlag = readArgvFlag(argv, i, "--output");
    if (outputFlag) {
      output = outputFlag.value;
      i = outputFlag.nextIndex;
    }
  }

  return { file, output };
}

/**
 * @param {string} userPath
 * @param {string} label
 * @returns {string}
 */
function resolveAllowedOutputPath(userPath, label) {
  const outputName = basename(userPath.replaceAll("\\", "/"));
  if (!/^[A-Za-z0-9._-]+\.json$/.test(outputName)) {
    throw new Error(
      `${label} must be a simple .json filename, got ${userPath}`,
    );
  }
  const outputDir = join(REPO_ROOT, "sdk/e2e/.debug/out");
  return join(outputDir, outputName);
}

/**
 * @param {CatalogEntry[]} mdEntries
 * @returns {string[]}
 */
function enumsFromMd(mdEntries) {
  return mdEntries
    .filter(
      (/** @type {CatalogEntry} */ entry) =>
        entry && typeof entry.content === "string",
    )
    .map((/** @type {CatalogEntry} */ entry) => String(entry.content));
}

/**
 * @param {SnapshotStage} stage
 */
function survivorCatalog(stage) {
  /** @type {{ json?: unknown[]; md?: unknown[] }} */
  const survivor = {};
  if (Array.isArray(stage.json)) {
    survivor.json = stage.json;
  }
  if (Array.isArray(stage.md)) {
    survivor.md = stage.md;
  }
  return survivor;
}

/**
 * @param {Record<string, SnapshotStage>} stages
 * @param {SnapshotStage} buildStage
 */
function survivorStageForSimpleSnapshot(stages, buildStage) {
  if (Array.isArray(stages.json) || Array.isArray(stages.md)) {
    return stages;
  }
  return buildStage;
}

/**
 * @param {SnapshotData} data
 */
function snapshotStages(data) {
  const stages = data.pruning?.decomposed_catalog ?? {};
  const buildStage = stages.build_index ?? {};

  if ("body" in data) {
    return {
      expected: data.body?.tools ?? [],
      buildStage,
      survivorStage: stages.rerank ?? buildStage,
    };
  }

  return {
    expected: data.tools ?? [],
    buildStage,
    survivorStage: survivorStageForSimpleSnapshot(stages, buildStage),
  };
}

/**
 * @param {JsonRecord[]} buildTools
 * @param {JsonRecord[]} expected
 */
function requireBuildTools(buildTools, expected) {
  if (buildTools.length === 0 && expected.length > 0) {
    throw new Error(
      "snapshot has no pruning.decomposed_catalog.build_index.tools; cannot rebuild catalog index",
    );
  }
}

/**
 * @param {{ json?: unknown[]; md?: unknown[] }} survivor
 */
function requireSurvivorCatalog(survivor) {
  const hasJson = Array.isArray(survivor.json) && survivor.json.length > 0;
  const hasMd = Array.isArray(survivor.md) && survivor.md.length > 0;
  if (!hasJson && !hasMd) {
    throw new Error("snapshot has no rerank json/md entries for decomposition");
  }
}

/**
 * @param {SnapshotData} data
 */
function extractSnapshotParts(data) {
  const { expected, buildStage, survivorStage } = snapshotStages(data);
  const buildTools = buildStage.tools ?? [];
  requireBuildTools(buildTools, expected);

  const survivor = survivorCatalog(survivorStage);
  requireSurvivorCatalog(survivor);

  return { buildTools, survivor, expected };
}

/**
 * @param {SnapshotData} data
 */
function catalogDictFromSnapshot(data) {
  const { buildTools } = extractSnapshotParts(data);
  const buildStage = data.pruning?.decomposed_catalog?.build_index ?? {};
  const enums = enumsFromMd(buildStage.md ?? []);
  const index = buildCatalogIndex(buildTools, enums);
  return index.toCatalogDict();
}

/**
 * @param {string[] | undefined} [argv]
 * @returns {boolean}
 */
export function hasExampleFileArg(argv = process.argv) {
  const envArgs = readEnvArgs();
  if (envArgs.file) {
    return true;
  }
  for (let i = 0; i < argv.length; i += 1) {
    if (readArgvFlag(argv, i, "--file")) {
      return true;
    }
  }
  return false;
}

/**
 * @param {string[] | undefined} [argv]
 */
export function runExampleFileE2E(argv = process.argv) {
  const { file: exampleFile, output: outputFile } = readTestArgs(argv);
  if (!exampleFile) {
    return;
  }

  const snapshotPath = resolveAllowedSnapshotPath(exampleFile);
  try {
    statSync(snapshotPath);
  } catch {
    throw new Error(
      `snapshot file not found under repo root ${REPO_ROOT}: ${exampleFile}`,
    );
  }
  const raw = readFileSync(snapshotPath, "utf8");
  const data = JSON.parse(raw);
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new TypeError(`expected JSON object in ${snapshotPath}`);
  }

  extractSnapshotParts(data);

  const catalog = catalogDictFromSnapshot(data);
  const jsonChunks = catalog.json ?? [];
  const mdChunks = catalog.md ?? [];

  if (jsonChunks.length === 0) {
    throw new Error("buildCatalogIndex produced no json chunks");
  }
  if (mdChunks.length === 0) {
    throw new Error("buildCatalogIndex produced no md enum chunks");
  }
  const foundDecomposed = jsonChunks.some(
    (/** @type {{ file_path?: string }} */ entry) =>
      typeof entry.file_path === "string" &&
      entry.file_path.includes("/schemas/decomposed/") &&
      entry.file_path.endsWith(".json"),
  );
  if (!foundDecomposed) {
    throw new Error("expected per-property decomposed json chunks");
  }

  const payload = `${JSON.stringify(catalog, null, 2)}\n`;
  if (outputFile) {
    const outputPath = resolveAllowedOutputPath(outputFile, "output path");
    mkdirSync(dirname(outputPath), { recursive: true });
    writeFileSync(outputPath, payload, "utf8");
    return;
  }
  process.stdout.write(payload);
}

/** TypeScript SDK for chunk-your-tools (Rust-backed tool schema decomposition). */

export { getVersion } from "./core.js";
export {
  CatalogIndex,
  anthropicToolToCatalogEntry,
  anthropicToolsToCatalogEntries,
  buildCatalogFromTools,
  buildCatalogIndex,
  catalogIndexToolSchemaMetadata,
  catalogToolCount,
  collectEnums,
  prepareToolEntry,
  truncateDescription,
} from "./build.js";
export {
  DecomposedCatalog,
  chunkSurvivorKey,
  loadCatalog,
  removedChunks,
  resolveBuildCatalog,
  retrieveCatalogToolCount,
  retrieveCore,
  retrieveTools,
  type DecomposedCatalogDict,
  type JsonRecord,
  type PolicyContextJs,
  type PolicyOptions,
  type RemovedChunksOptions,
  type RetrieveCoreOptions,
  type RetrieveToolsOptions,
} from "./retrieve.js";
export {
  configureRuntimeDefaults,
  defaultMcpPolicy,
  defaultSystemPolicy,
  decomposedScore,
  emptyOptionalFallbackK,
  enumScore,
  rerankScore,
  type RuntimeDefaultsConfig,
} from "./runtime-defaults.js";
export {
  builderMemoryOnly,
  catalogPrefix,
  configurePathConstants,
  defaultCatalogDir,
  decomposedPrefix,
  decomposedRoot,
  getRootToolKey,
  jsonExt,
  mdExt,
  toDecomposedKey,
  toolIdFromDecomposedRel,
  writeCatalogPrune,
} from "./paths.js";
export { CatalogBuilder, writeCatalogIndex } from "./catalog-io.js";
export {
  configureTokenizerDefaults,
  countJsonTokens,
  countTokens,
  countTokensBatch,
} from "./tokens.js";
export {
  recomposeToolsFromNames,
  resolveSurvivorsFromNames,
} from "./survivors.js";
export type { ToolSchemaMetadata, ToolSchemaTokenFileEntry } from "./types.js";

// Full policy surface (mirrors chunk_your_tools.policies).
export * from "./policies.js";

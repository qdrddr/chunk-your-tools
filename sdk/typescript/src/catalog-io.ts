/** Catalog disk I/O and builder (Rust-backed). */

import { CatalogIndex } from "./build.js";
import {
  CatalogBuilderNative,
  loadCatalogIndexFromDirNative,
  writeCatalogIndexNative,
} from "./native.js";
import type { JsonRecord } from "./types.js";

export function writeCatalogIndex(
  index: JsonRecord,
  outputDir?: string | null,
  prune?: boolean | null,
): void {
  writeCatalogIndexNative(index, outputDir ?? undefined, prune ?? undefined);
}

export function loadCatalogIndexFromDir(dirPath: string): CatalogIndex {
  const result = loadCatalogIndexFromDirNative(dirPath) as {
    tools: JsonRecord[];
    files: Record<string, string>;
  };
  return new CatalogIndex(result.tools, result.files);
}

export type CatalogBuilder = InstanceType<typeof CatalogBuilderNative>;

export { CatalogBuilderNative as CatalogBuilder };

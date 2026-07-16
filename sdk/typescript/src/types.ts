export type JsonRecord = Record<string, unknown>;

export function isJsonRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/** Classification for one file in decomposed catalog metadata. */
export type DecomposedMetadataEntryType = "tool" | "property" | "enum";

/** Cached token metadata for one tool schema file in a catalog index. */
export interface ToolSchemaTokenFileEntry {
  file_path: string;
  token_count: number | null;
}

/** Decomposed catalog metadata entry (includes file classification). */
export interface DecomposedToolSchemaTokenFileEntry extends ToolSchemaTokenFileEntry {
  type: DecomposedMetadataEntryType;
}

/** Cached full/decomposed tool schema token metadata from catalog index files. */
export interface ToolSchemaMetadata {
  full: ToolSchemaTokenFileEntry | { files: ToolSchemaTokenFileEntry[] } | null;
  decomposed: DecomposedToolSchemaTokenFileEntry[] | null;
}

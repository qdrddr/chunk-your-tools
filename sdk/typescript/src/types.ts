export type JsonRecord = Record<string, unknown>;

export function isJsonRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/** Cached token metadata for one tool schema file in a catalog index. */
export interface ToolSchemaTokenFileEntry {
  file_path: string;
  token_count: number | null;
}

/** Cached full/decomposed tool schema token metadata from catalog index files. */
export interface ToolSchemaMetadata {
  full: ToolSchemaTokenFileEntry | { files: ToolSchemaTokenFileEntry[] } | null;
  decomposed: ToolSchemaTokenFileEntry[] | null;
}

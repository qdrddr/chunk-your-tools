package chunkyourtools

// WriteCatalogIndex writes a catalog index JSON snapshot to a directory.
func WriteCatalogIndex(indexJSON, outputDir string, prune bool) error {
	return cgoWriteCatalogIndex(indexJSON, outputDir, prune)
}

// LoadCatalogIndexFromDir reads a catalog index from a directory on disk.
func LoadCatalogIndexFromDir(dirPath string) (string, error) {
	return cgoLoadCatalogIndexFromDir(dirPath)
}

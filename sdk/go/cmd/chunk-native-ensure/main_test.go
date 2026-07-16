package main

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"

	"github.com/qdrddr/chunk-your-tools/sdk/go/v2/moduleversion"
)

func TestResolveVersionUsesModuleVersion(t *testing.T) {
	t.Setenv("CHUNK_YOUR_TOOLS_RELEASE_VERSION", "")
	if got := resolveVersion(""); got != moduleversion.Version {
		t.Fatalf("resolveVersion() = %q, want %q", got, moduleversion.Version)
	}
	if got := resolveVersion("v1.2.3"); got != "1.2.3" {
		t.Fatalf("resolveVersion(flag) = %q, want 1.2.3", got)
	}
}

func TestIsSDKModuleRoot(t *testing.T) {
	dir := t.TempDir()
	goMod := filepath.Join(dir, "go.mod")
	if err := os.WriteFile(goMod, []byte("module github.com/qdrddr/chunk-your-tools/sdk/go/v2\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if !isSDKModuleRoot(dir) {
		t.Fatal("expected sdk module root")
	}
	if isSDKModuleRoot(t.TempDir()) {
		t.Fatal("unexpected sdk module root for empty dir")
	}
}

func TestLookupChecksum(t *testing.T) {
	sumData := []byte("abc123  chunk-your-tools-ffi-aarch64-apple-darwin.tar.gz\n")
	got, err := lookupChecksum(sumData, "chunk-your-tools-ffi-aarch64-apple-darwin.tar.gz")
	if err != nil {
		t.Fatal(err)
	}
	if got != "abc123" {
		t.Fatalf("lookupChecksum() = %q, want abc123", got)
	}
	if _, err := lookupChecksum(sumData, "missing.tar.gz"); err == nil {
		t.Fatal("expected error for missing archive")
	}
}

func TestVerifyDownloadSHA256(t *testing.T) {
	data := []byte("payload")
	sum := sha256.Sum256(data)
	expected := hex.EncodeToString(sum[:])
	if err := verifyDownloadSHA256(data, expected); err != nil {
		t.Fatalf("verifyDownloadSHA256() = %v", err)
	}
	if err := verifyDownloadSHA256(data, "deadbeef"); err == nil {
		t.Fatal("expected mismatch error")
	}
}

func TestCopyArtifactsIncludesSharedByDefault(t *testing.T) {
	src := t.TempDir()
	dest := t.TempDir()
	triplet := "aarch64-apple-darwin"

	for name, content := range map[string]string{
		"libchunk_your_tools.a":     "static",
		"libchunk_your_tools.dylib": "shared",
		"chunk_your_tools.h":        "header",
	} {
		if err := os.WriteFile(filepath.Join(src, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if err := copyArtifacts(src, dest, triplet, false); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dest, "libchunk_your_tools.dylib")); err != nil {
		t.Fatal("expected shared lib when staticOnly is false")
	}
}

func TestEnsureNativeDownloadsWhenCacheEmpty(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_NATIVE_ENSURE_INTEGRATION") != "1" {
		t.Skip("set CHUNK_YOUR_TOOLS_NATIVE_ENSURE_INTEGRATION=1 to run release download test")
	}
	cacheRoot := t.TempDir()
	triplet, err := hostTriplet()
	if err != nil {
		t.Fatal(err)
	}
	dest, _, err := ensureNative(ensureConfig{
		version:   moduleversion.Version,
		repo:      defaultRepo,
		triplet:   triplet,
		cacheRoot: cacheRoot,
		force:     true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if !hasNativeLibs(dest, triplet) {
		t.Fatalf("expected native libs in %s", dest)
	}
}

func TestHasNativeLibsWindowsImportLib(t *testing.T) {
	dir := t.TempDir()
	triplet := "x86_64-pc-windows-msvc"
	if err := os.WriteFile(filepath.Join(dir, "chunk_your_tools.dll.lib"), []byte("import"), 0o644); err != nil {
		t.Fatal(err)
	}
	if !hasNativeLibs(dir, triplet) {
		t.Fatal("expected chunk_your_tools.dll.lib to satisfy hasNativeLibs on Windows")
	}
}

func TestResolveTripletUsesEnv(t *testing.T) {
	t.Setenv("CHUNK_YOUR_TOOLS_RUST_TARGET", "aarch64-unknown-linux-gnu")
	got, err := resolveTriplet()
	if err != nil {
		t.Fatal(err)
	}
	if got != "aarch64-unknown-linux-gnu" {
		t.Fatalf("resolveTriplet() = %q", got)
	}
}

func TestCopyArtifactsStaticOnlyWindows(t *testing.T) {
	src := t.TempDir()
	dest := t.TempDir()
	triplet := "x86_64-pc-windows-msvc"

	for name, content := range map[string]string{
		"chunk_your_tools.dll":     "shared",
		"chunk_your_tools.dll.lib": "import",
		"chunk_your_tools.h":       "header",
	} {
		if err := os.WriteFile(filepath.Join(src, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if err := copyArtifacts(src, dest, triplet, true); err != nil {
		t.Fatal(err)
	}
	if !hasNativeLibs(dest, triplet) {
		t.Fatal("expected import lib to satisfy static-only Windows install")
	}
	if _, err := os.Stat(filepath.Join(dest, "chunk_your_tools.dll")); !os.IsNotExist(err) {
		t.Fatal("shared dll should be omitted with staticOnly")
	}
}

func TestCopyArtifactsStaticOnly(t *testing.T) {
	src := t.TempDir()
	dest := t.TempDir()
	triplet := "aarch64-apple-darwin"

	for name, content := range map[string]string{
		"libchunk_your_tools.a":     "static",
		"libchunk_your_tools.dylib": "shared",
		"chunk_your_tools.h":        "header",
	} {
		if err := os.WriteFile(filepath.Join(src, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if err := copyArtifacts(src, dest, triplet, true); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dest, "libchunk_your_tools.a")); err != nil {
		t.Fatal("missing static lib")
	}
	if _, err := os.Stat(filepath.Join(dest, "chunk_your_tools.h")); err != nil {
		t.Fatal("missing header")
	}
	if _, err := os.Stat(filepath.Join(dest, "libchunk_your_tools.dylib")); !os.IsNotExist(err) {
		t.Fatal("shared lib should be omitted with staticOnly")
	}
}

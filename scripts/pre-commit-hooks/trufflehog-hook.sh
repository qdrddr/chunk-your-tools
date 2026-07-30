#!/usr/bin/env bash
# TruffleHog pre-commit wrapper for repos where .git is a gitdir file (submodules).
set -euo pipefail

ROOT="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
cd "$ROOT"

restore_gitdir_file() {
	if [[ -n "${GITDIR_FILE_BACKUP:-}" && -L .git ]]; then
		rm .git
		mv "$GITDIR_FILE_BACKUP" .git
	fi
}

if [[ -f .git && ! -d .git ]]; then
	GITDIR="$(git rev-parse --git-dir)"
	GITDIR_FILE_BACKUP="$ROOT/.git-trufflehog-backup-$$"
	mv .git "$GITDIR_FILE_BACKUP"
	ln -s "$GITDIR" .git
	trap restore_gitdir_file EXIT
fi

exec trufflehog git file://. --since-commit HEAD --results=verified --fail "$@"

# Legal and license compliance

This directory holds the **single source of truth** for license policy and
FOSSA-style obligation tracking for chunk-your-tools. It complements the
root-level files that ship with distributions:

| File | Purpose |
| ------ | --------- |
| [`../NOTICE`](../NOTICE) | Legally required third-party attribution (plain text; FOSSA-compatible) |
| [`../LICENSE`](../LICENSE) | Apache License 2.0 full text for this project |
| [`policy.toml`](policy.toml) | **Canonical SPDX allow-list, obligations, and compatibility notes** |

## Policy (`policy.toml`)

Edit `legal/policy.toml` when adding allowed licenses, FOSSA-style obligation
rules, or NOTICE-tracked components. Everything else reads from this file:

| Consumer | How it uses `policy.toml` |
| ---------- | --------------------------- |
| `scripts/legal/audit-npm.sh` | `--onlyAllow` via `scripts/legal/lib/policy.py` |
| `scripts/legal/audit-c.sh` | First-party license check |
| `deny.toml` | `[licenses].allow` synced by `./scripts/legal/sync-policy.sh` |
| `legal/license-compatibility.txt` | Generated compatibility table |
| `legal/obligations/` | Generated obligation matrices |

Sync `deny.toml` after editing policy:

```bash
./scripts/legal/sync-policy.sh
```

## Generated contents

- [`license-compatibility.txt`](license-compatibility.txt) — compatibility summary derived from `policy.toml`
- [`obligations/`](obligations/) — distribution obligations grouped by type

Regenerate reports and refresh generated files with:

```bash
./scripts/legal/audit-all.sh --with-dev
```

Raw per-ecosystem JSON/CSV audit output is written under `scripts/legal/output/`.

## FOSSA workflow

[FOSSA](https://fossa.com/) reads the root [`.fossa.yml`](../.fossa.yml) for project
identity and the root [`NOTICE`](../NOTICE) for attribution reports. Mirror
`legal/policy.toml` in the FOSSA dashboard license policy so CI and local audits agree.

Keep `NOTICE` limited to legally required notices in plain text (no Markdown tables).

Use this `legal/` directory for:

- the canonical license policy (`policy.toml`)
- generated obligation matrices and compatibility tables
- dependency-path context that does not belong in `NOTICE`

import assert from "node:assert/strict";
import { execFileSync, execSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  PolicyContext,
  applyToolKind,
  batchToolPassThrough,
  effectivePolicy,
  policyContextFromValues,
  scoringPolicyContext,
} from "../policies.js";
import { buildCatalogIndex, catalogIndexToolSchemaMetadata } from "../build.js";
import { getVersion } from "../core.js";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "../../../..");

function skipParity(): boolean {
  return process.env.CYT_SKIP_PARITY === "1";
}

function uvAvailable(): boolean {
  try {
    execFileSync("uv", ["--version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function pythonAvailable(): boolean {
  if (!uvAvailable()) {
    return false;
  }
  try {
    execSync(
      'uv run --project sdk/python python -c "import chunk_your_tools"',
      {
        cwd: repoRoot,
        stdio: "ignore",
      },
    );
    return true;
  } catch {
    return false;
  }
}

function pythonJSON(script: string): unknown {
  const out = execFileSync(
    "uv",
    ["run", "--project", "sdk/python", "python", "-c", script.trim()],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );
  return JSON.parse(out.trim());
}

function assertJsonEqual(got: unknown, want: unknown): void {
  assert.deepEqual(
    JSON.parse(JSON.stringify(got)),
    JSON.parse(JSON.stringify(want)),
  );
}

test("parity batchToolPassThrough matches Python reference", () => {
  if (skipParity()) {
    return;
  }
  if (!pythonAvailable()) {
    return;
  }

  const want = pythonJSON(`
import json
from chunk_your_tools._native import policy_context_from_values, batch_tool_pass_through
cfg = {"pruning": {"tools": {"policy": {"system_tool": "always_include", "mcp_tool": "always_include"}}}}
ctx = policy_context_from_values(cfg)
print(json.dumps(batch_tool_pass_through(ctx, ["Agent", "grep"])))
`);

  const ctx = policyContextFromValues({
    pruning: {
      tools: {
        policy: {
          system_tool: "always_include",
          mcp_tool: "always_include",
        },
      },
    },
  });
  const got = batchToolPassThrough(["Agent", "grep"], ctx);
  assertJsonEqual(got, want);
});

test("parity effectivePolicy respects tool_kind override", () => {
  if (skipParity()) {
    return;
  }
  if (!pythonAvailable()) {
    return;
  }

  const want = pythonJSON(`
import json
from chunk_your_tools._native import PolicyContext, effective_policy
ctx = PolicyContext()
ctx.system_policy = "prune_optional"
ctx.mcp_policy = "prune_all"
ctx.tool_kind = "mcp"
print(json.dumps(effective_policy(ctx, "tools.demo.org.search")))
`) as string;

  const ctx = new PolicyContext("prune_optional", "prune_all");
  applyToolKind(ctx, "mcp");
  assert.equal(effectivePolicy("tools.demo.org.search", ctx), want);
});

test("scoringPolicyContext copies toolKind", () => {
  const ctx = new PolicyContext(
    "prune_optional_descriptions",
    "prune_all_descriptions",
  );
  applyToolKind(ctx, "mcp");
  const scoring = scoringPolicyContext(ctx);
  assert.equal(scoring.toolKind, "mcp");
  assert.equal(scoring.systemPolicy, "prune_optional");
  assert.equal(scoring.mcpPolicy, "prune_all");
});

test("parity buildCatalogIndex smoke matches Python reference", () => {
  if (skipParity()) {
    return;
  }
  if (!pythonAvailable()) {
    return;
  }

  const want = pythonJSON(`
import json
from chunk_your_tools._native import build_catalog_index
print(json.dumps(build_catalog_index([], [])))
`);

  const index = buildCatalogIndex([], []);
  const got = {
    tools: index.tools,
    files: index.files,
  };
  assertJsonEqual(got, want);
});

test("parity catalogIndexToolSchemaMetadata matches Python reference", () => {
  if (skipParity() || !pythonAvailable()) {
    return;
  }

  const want = pythonJSON(`
import json
from chunk_your_tools import catalog_index_tool_schema_metadata
print(json.dumps(catalog_index_tool_schema_metadata({"tools": [], "files": {}})))
`);
  const got = catalogIndexToolSchemaMetadata({ tools: [], files: {} });
  assertJsonEqual(got, want);
});

test("parity getVersion matches Python reference", () => {
  if (skipParity() || !pythonAvailable()) {
    return;
  }

  const want = pythonJSON(`
import json
from chunk_your_tools import get_version
print(json.dumps(get_version()))
`);
  assertJsonEqual(getVersion(), want);
});

import assert from "node:assert/strict";
import test from "node:test";

import { batchToolPassThrough, PolicyContext } from "chunk-your-tools";

test("batchToolPassThrough from npm package", () => {
  const ctx = new PolicyContext("always_include", "always_include");
  const flags = batchToolPassThrough(["Agent", "grep"], ctx);
  assert.ok(flags.every((flag) => flag === true));
});

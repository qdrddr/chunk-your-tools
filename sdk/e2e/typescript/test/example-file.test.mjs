import test from "node:test";

import { hasExampleFileArg, runExampleFileE2E } from "./example-snapshot.mjs";

test(
  "decompose from example file",
  {
    skip: hasExampleFileArg()
      ? false
      : "pass --file to run against a local debug snapshot",
  },
  () => {
    runExampleFileE2E();
  },
);

/** Named survivor mapping and tool recomposition helpers. */

import type { JsonRecord } from "./retrieve.js";
import {
  recomposeToolsFromNamesNative,
  resolveSurvivorsFromNamesNative,
} from "./native.js";

export function resolveSurvivorsFromNames(
  index: JsonRecord,
  survivors: JsonRecord,
): JsonRecord {
  return resolveSurvivorsFromNamesNative(index, survivors) as JsonRecord;
}

export function recomposeToolsFromNames(
  tools: JsonRecord[],
  survivors: JsonRecord,
  policyContext?: JsonRecord,
): JsonRecord[] {
  return recomposeToolsFromNamesNative(
    tools,
    survivors,
    policyContext,
  ) as JsonRecord[];
}

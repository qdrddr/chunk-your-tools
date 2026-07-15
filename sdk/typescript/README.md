# chunk-your-tools-sdk

TypeScript/Node bindings for the [chunk-your-tools](https://crates.io/crates/chunk-your-tools) Rust library.

## Install

```bash
npm install chunk-your-tools-sdk
```

## Usage

```typescript
import {
  buildCatalogFromTools,
  recomposeToolsFromNames,
  resolveSurvivorsFromNames,
} from "chunk-your-tools-sdk";

const index = buildCatalogFromTools(tools);
const pruned = recomposeToolsFromNames(tools, {
  tools: ["Agent"],
  properties: { Agent: ["model"] },
  enums: ["opus"],
});
```

## Development

```bash
npm ci
npm run build
npm test
```

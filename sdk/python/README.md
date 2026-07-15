# chunk-your-tools-sdk

Python SDK for [chunk-your-tools](https://crates.io/crates/chunk-your-tools) — tool schema decomposition and recomposition.

```bash
pip install chunk-your-tools-sdk
```

```python
from chunk_your_tools import build_catalog_from_tools, recompose_tools_from_names

index = build_catalog_from_tools(tools)
pruned = recompose_tools_from_names(tools, survivors)
```

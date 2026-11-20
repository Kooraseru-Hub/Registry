---
title: Tests and benchmarks
description: Reproduce Registry lookup tests and compare cold and warm module access.
---

From MSYS2 on Windows with Node.js, the Windows Python launcher, and Roblox Studio installed, run these suites from the repository root.

| Suite | What it exercises |
| --- | --- |
| `Lookup` | Typed paths, real ModuleScripts, and lookup after a module failure |
| `RequireForms` | Direct require using different reference forms and Registry lookup |
| `Matrix` | First loads and cached lookups across workloads |

```sh
bash tests/registry/Studio/run.sh Lookup
bash tests/registry/Studio/run.sh RequireForms
bash tests/registry/Studio/run.sh Matrix
```

Each run builds a fresh fixture and writes its Studio log under `build/studio-runner`.

Cold trials load fresh ModuleScripts. Warm trials prime both implementations before timing. Check the [benchmark methodology, raw trials, and heatmaps](https://github.com/Kooraseru-Hub/Registry/tree/source/tests/registry/Benchmark) for the workload, timing boundaries, and the Studio version used for the published samples.

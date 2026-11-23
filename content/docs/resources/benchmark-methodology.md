---
title: Benchmark methodology
description: How Registry cold and warm lookups are measured in Studio.
---

Registry's benchmark suites run in Roblox Studio and compare matched workloads, not just elapsed time for a single lookup.

## Workloads

| Suite | Purpose |
| --- | --- |
| `Lookup` | Valid paths, successful ModuleScripts, and failed loads. |
| `RequireForms` | Direct `require` with different reference forms versus Registry lookup. |
| `Matrix` | Cold and warm calls over multiple workloads. |

Cold trials use fresh ModuleScripts. Warm trials prime the implementations before measurement. The benchmark alternates method order and excludes fixture setup, registration, warmup, and checksum verification from timed loops.

## Run locally

On Windows with Roblox Studio and Node.js available, use MSYS2 or Git Bash. WSL also needs Windows interop.

```sh
bash tests/registry/Studio/run.sh Lookup
bash tests/registry/Studio/run.sh RequireForms
bash tests/registry/Studio/run.sh Matrix
```

For the repository's combined benchmark and chart output:

```sh
bash tests/registry/Studio/benchmark-build.sh
```

Generated logs and artifacts live under `build/artifacts/tests/` and `build/artifacts/benchmarks/`. Compare results only on comparable machines, Studio versions, and workloads. A faster warm lookup does not imply faster first-load behavior.

See the [benchmark source and methodology](https://github.com/Kooraseru-Hub/Registry/tree/source/tests/registry/benchmarks).

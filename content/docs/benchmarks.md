---
title: Tests and benchmarks
description: Reproduce Registry lookup tests and compare cold and warm module access.
sidebar:
  label: Tests and benchmarks
---

The repository includes Studio tests for typed paths, real ModuleScripts, failed loads, and lookup performance.

## Run the suites

With Windows Roblox Studio and Node.js installed, use MSYS2 or Git Bash. WSL additionally needs Windows interop.

```sh
bash tests/registry/Studio/run.sh Lookup
bash tests/registry/Studio/run.sh RequireForms
bash tests/registry/Studio/run.sh Matrix
```

Logs are written under `build/artifacts/tests/`.

## Measurement notes

Cold lookups include the initial ModuleScript `require`. Warm lookups use already loaded modules. Results depend on the workload, machine, and Studio version; neither measurement is interchangeable with the other.

The [benchmark methodology](./resources/benchmark-methodology/) describes timed loops and output, and the [source tests](https://github.com/Kooraseru-Hub/Registry/tree/source/tests/registry) provide the fixtures.

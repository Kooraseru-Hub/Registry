#!/usr/bin/env bash
set -euo pipefail

/usr/bin/mkdir -p build/artifacts/benchmarks
results=$(/usr/bin/mktemp -d build/artifacts/benchmarks/local-XXXXXXXX)
/usr/bin/bash tests/registry/Studio/run.sh Matrix "$results"

printf 'Building README\n'
export REGISTRY_BENCHMARK_RESULTS="$results"
node dependencies/packages/core/dependencyLoader/index.ts --exec luau.lute run .github/components/governance/branches/build/run.luau

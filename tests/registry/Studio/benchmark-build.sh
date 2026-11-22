#!/usr/bin/env bash
set -euo pipefail

/usr/bin/mkdir -p build/artifacts/benchmarks
results=$(/usr/bin/mktemp -d build/artifacts/benchmarks/local-XXXXXXXX)
/usr/bin/bash tests/registry/Studio/run.sh Matrix "$results"

printf 'Building README\n'
export REGISTRY_BENCHMARK_RESULTS="$results"
export CI_EVENT=workflow_dispatch CI_OPERATION=build CI_GRAPH_RUN=true CI_PHASE=build
node dependencies/packages/core/dependencyLoader/index.ts --exec tools.ciEngine native --stage build

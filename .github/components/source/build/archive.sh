#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/artifacts/source
git archive --format=zip --output=build/artifacts/source/Registry.zip HEAD source/Registry.luau LICENSE

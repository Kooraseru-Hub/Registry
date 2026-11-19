#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/artifacts
git archive --format=zip --output=build/artifacts/Registry.zip HEAD source/Registry LICENSE

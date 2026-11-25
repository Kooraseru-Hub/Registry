#!/usr/bin/env bash
set -euo pipefail

commit=$(git rev-parse --verify "${1:-HEAD}^{commit}")
output=${2:-build/artifacts/source}
mkdir -p "$output"

if git cat-file -e "$commit:source/Registry.luau" 2>/dev/null; then
    model_source=source/Registry.luau
elif git cat-file -e "$commit:src/Registry/init.luau" 2>/dev/null; then
    model_source=src/Registry
elif git cat-file -e "$commit:Source Code/Registry.lua" 2>/dev/null; then
    model_source="Source Code/Registry.lua"
elif git cat-file -e "$commit:Registry.lua" 2>/dev/null; then
    model_source=Registry.lua
else
    printf 'No supported Registry layout at %s\n' "$commit" >&2
    exit 1
fi

git archive --format=zip --output="$output/Registry.zip" "$commit" "$model_source" LICENSE
node "${CI_PACKAGES_DIR:-build/ci-packages}/packages/roblox/model.cjs" "$commit" "$model_source" "$output/Registry.rbxm" Registry

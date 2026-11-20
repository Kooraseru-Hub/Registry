#!/usr/bin/env bash
set -euo pipefail

# Run from the repository root. Keep Linux dependencies and build I/O inside Docker.
repository=$(pwd)
case "$OSTYPE" in
  msys*|cygwin*)
    export PATH="/usr/bin:$PATH"
    repository=$(cygpath -m "$repository")
    ;;
esac

export MSYS_NO_PATHCONV=1
exec docker run --rm --init \
  --name kooraseru-hub-registry-ci --hostname registry-ci \
  --label org.opencontainers.image.source=https://github.com/Kooraseru-Hub/Registry \
  --mount "type=bind,source=$repository,target=/repo,readonly" \
  node:24-bookworm bash -euo pipefail -c '
    git config --global --add safe.directory /repo
    git clone --no-checkout --local --no-hardlinks /repo /workspace
    cd /workspace
    git remote set-url origin "$(git -C /repo remote get-url origin)"
    git read-tree HEAD
    git -C /repo ls-files -z --deduplicate | tar -C /repo --null --ignore-failed-read -T - -cf - | tar -xf -
    node dependencies/packages/core/dependencyLoader/index.ts --exec tools.ciEngine native-validate
  '

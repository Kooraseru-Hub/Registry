# Contributing to Registry

Use the `source` branch to propose changes. The `main` branch is generated from this checkout for distribution.

- [Public README](content/docs/repository/README.md) is the editable source for the README published on `main`.
- [Registry.luau](source/Registry.luau) is the library.
- [Registry documentation](content/docs/index.md) is the source for GitHub Pages.
- [Studio tests](tests/registry/Studio/README.md) and [benchmarks](tests/registry/benchmarks/README.md) describe how to reproduce results.

## Native CI

CI validates pushes and pull requests, builds historical release assets, generates documentation and stages the distribution branch. Publish defaults to rehearsal. On the default branch, select releases, branches (including verified DevForum synchronization), or pages. The optional Benchmark workflow runs Roblox Open Cloud measurements in its protected environment; provide its successful run ID and attempt to Publish to refresh the benchmark snapshot. Without a new benchmark the existing published snapshot is reused.

Local archive builds use the standalone CI-Packages CLI: clone the package repository at the pinned workflow revision into `build/ci-packages` (or set `CI_PACKAGES_DIR`), then run `bash .github/components/source/build/archive.sh`. Local Studio tests remain opt-in.

## Verify changes

From the repository root, set up the pinned tools and run Preflight.

```sh
node dependencies/packages/core/dependencyLoader/index.ts
node dependencies/packages/checks/preflightChecker/index.ts
node dependencies/packages/checks/preflightChecker/index.ts --rules
```

For Luau editor completion, generate the ignored root sourcemap with `node .vscode/config/luau/generate-sourcemap.cjs`. Run it again after changing the test hierarchy.

For Registry behavior changes, run `bash tests/registry/Studio/run.sh Lookup` with Node.js and Windows Roblox Studio installed. The launcher supports MSYS2, Git Bash, and WSL with Windows interop. Include the checks you ran in the pull request.

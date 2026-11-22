# Contributing to Registry

Use the `source` branch to propose changes. The `main` branch is generated from this checkout for distribution.

- [Public README](content/docs/repository/README.md) is the editable source for the README published on `main`.
- [Registry.luau](source/Registry.luau) is the library.
- [Registry documentation](content/docs/index.md) is the source for GitHub Pages.
- [Studio tests](tests/registry/Studio/README.md) and [benchmarks](benchmarks/registry/README.md) describe how to reproduce results.

## Verify changes

From the repository root, set up the pinned tools and run Preflight.

```sh
node dependencies/packages/core/dependencyLoader/index.ts
node dependencies/packages/checks/preflightChecker/index.ts --ci
node dependencies/packages/checks/preflightChecker/index.ts --rules
```

For Luau editor completion, generate the ignored root sourcemap with `node .vscode/config/luau/generate-sourcemap.cjs`. Run it again after changing the test hierarchy.

For Registry behavior changes, run `bash tests/registry/Studio/run.sh Lookup` with Node.js and Windows Roblox Studio installed. The launcher supports MSYS2, Git Bash, and WSL with Windows interop. Include the checks you ran in the pull request.

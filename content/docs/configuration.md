---
title: Registrations and editor setup
description: Choose registry paths and configure the repository editor fixture.
---

## Choose paths

Use string keys such as `"Game/Settings"` or `"UI/Theme"`. Slashes let you group related entries by convention. Each key is an exact lookup, so `"UI/Theme"` and `"ui/theme"` are different keys.

A shared ModuleScript can return a registry to any consumer that requires it. Call `Registry.Register` again with a different table when you need an independent set of paths. Use instances that are accessible from the environment where consumers run.

## Generate the repository sourcemap

For this repository in VS Code, run the following from its root.

```sh
node .vscode/config/luau/generate-sourcemap.cjs
```

The Luau language server reads the generated root `sourcemap.json`. It maps the library and Studio test tree using `tests/registry/Studio/aliases.json`. Rerun the generator after moving or adding test scripts. The map is ignored by Git and is only needed for repository tooling.

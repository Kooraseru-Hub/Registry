---
title: Registrations and editor setup
description: Choose exact registry paths and configure repository editor completion.
slug: configuration
sidebar:
  label: Registrations and editor setup
---

## Choose paths

Use string keys such as `"Game/Settings"` or `"UI/Theme"`. Slashes group names by convention only. Each key is an exact lookup; `"UI/Theme"` and `"ui/theme"` are different keys.

```luau
const Registry = require("@game/ReplicatedFirst/Registry")
return Registry.Register({
    ["Game/Settings"] = script.Parent.Settings,
    ["UI/Theme"] = "dark",
})
```

Require this registration ModuleScript from consumers instead of calling `Register` separately in every script. Each `Register` invocation creates its own registry instance and cache.

Use ModuleScripts that are accessible from the environment where consumers run. Do not assume client and server share a require cache.

## Type inference

Known table keys give `Get` an inferred union of valid paths. A generic string-keyed dictionary weakens editor completion. The lookup result is still `unknown`, as detailed in [`Resolvable<Entries>`](../reference/types/resolvable/).

## VS Code repository fixture

For this repository, generate the Luau sourcemap from the root:

```sh
node .vscode/config/luau/generate-sourcemap.cjs
```

The generated `sourcemap.json` maps the library and Studio fixtures using `tests/registry/Studio/aliases.json`. Rerun it after moving or adding test scripts. It is ignored by Git and is needed only for repository tooling.

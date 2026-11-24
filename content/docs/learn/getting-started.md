---
title: Getting started
description: Install Registry and make a first typed path lookup in Roblox Studio.
slug: getting-started
sidebar:
  label: Getting started
---

## Install

Choose one installation method:

1. **Studio model (recommended):** download `Registry.rbxm` from the [2.0.0 release](https://github.com/Kooraseru-Hub/Registry/releases/tag/2.0.0). Import the model into Studio and place the resulting `Registry` ModuleScript under `ReplicatedFirst`.
2. **Source:** copy [`source/Registry.luau`](https://github.com/Kooraseru-Hub/Registry/blob/main/source/Registry.luau) (also included in `Registry.zip`) into a ModuleScript named `Registry` under `ReplicatedFirst`.

Use `ReplicatedFirst` for early client bootstrappers, or `ReplicatedStorage` for ordinary shared code; adjust the require path accordingly. Early replication of Registry does not make its registered dependencies replicate earlier. Wait for any dependencies outside ReplicatedFirst when necessary.

Enable the new Luau type solver under **Workspace > Scripting > UseNewLuauTypeSolver**.

## Create an entry

Create a ModuleScript named `Settings` under `ReplicatedStorage`:

```luau
--!strict
return table.freeze({ RoundLength = 60 })
```

Create a sibling ModuleScript named `Registrations`:

```luau
--!strict
const Registry = require("@game/ReplicatedFirst/Registry")

return Registry.Register({
    ["Game/Settings"] = script.Parent.Settings,
})
```

## Look up the export

From another script:

```luau
--!strict
const registry = require("@game/ReplicatedStorage/Registrations")
const settings, ok = registry:Get("Game/Settings")

if ok then
    print(settings)
else
    warn(settings)
end
```

The first lookup requires `Settings`; later lookups reuse the cached export while the registration points to the same ModuleScript.

The path is type-checked from the registration keys, but the result is still `unknown`. Check [lookup results and errors](../learn/lookup-results/) before accessing members of an export.

Continue with [registrations and editor setup](../configuration/) or the [API reference](../reference/).

---
title: Getting started
description: Install Registry and make a first typed path lookup in Roblox Studio.
slug: getting-started
sidebar:
  label: Getting started
---

## Install

Copy [`source/Registry.luau`](https://github.com/Kooraseru-Hub/Registry/blob/source/source/Registry.luau) into a ModuleScript named `Registry` under `ReplicatedStorage`.

Enable the new Luau type solver in Studio under **Workspace > Scripting > UseNewLuauTypeSolver**.

## Create an entry

Create a ModuleScript named `Settings` under `ReplicatedStorage`:

```luau
--!strict
return table.freeze({ RoundLength = 60 })
```

Create a sibling ModuleScript named `Registrations`:

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

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

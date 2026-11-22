---
title: Getting started
description: Install Registry in Studio and look up a ModuleScript from a separate script.
slug: getting-started
sidebar:
  order: 2
---

## Install

Copy [Registry.luau](https://github.com/Kooraseru-Hub/Registry/blob/source/source/Registry.luau) into a ModuleScript named `Registry` in `ReplicatedStorage`. Enable the new Luau type solver in Studio under **Workspace > Scripting > UseNewLuauTypeSolver**.

## Register a ModuleScript

Create a ModuleScript named `Settings` in `ReplicatedStorage` and give it this body.

```luau
--!strict
return table.freeze({ RoundLength = 60 })
```

Create a sibling ModuleScript named `Registrations`.

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

return Registry.Register({
    ["Game/Settings"] = script.Parent.Settings,
})
```

## Look up the result

From a separate script, require the shared registration and pass one of its keys to `Get`.

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

The first call loads `Settings` and returns its export. Next, [organize your registrations](../configuration/) or check the [API reference](../api/) for return values and errors.

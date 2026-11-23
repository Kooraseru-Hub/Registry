---
title: Registry.Register(entries)
description: Create a typed Registry object from a table of named entries.
sidebar:
  label: Register(entries)
---

Creates and returns a registry for a registration table.

## Signature

```luau
Register<Entries>(entries: Entries): Registry<Resolvable<Entries>>
```

## Parameters

| Parameter | Type | Description |
| --- | --- | --- |
| `entries` | `Entries` | A table whose keys are lookup paths and whose values are ModuleScripts or plain values. |

String keys are recommended. The exact key is used for lookup; a slash in a key is a naming convention, not a request to traverse a hierarchy.

## Returns

A [`Registry<Resolvable<Entries>>`](../../types/registry/) object with a `Get` method. The returned registry object is frozen. **The original entry table is not frozen or copied**; external changes to that table affect later lookups.

## Example

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

return Registry.Register({
    ["Game/Settings"] = script.Parent.Settings,
    ["UI/Theme"] = "dark",
    ["Features/Enabled"] = false,
})
```

This produces a registry that accepts the three literal paths shown above. Requiring the registration ModuleScript in another script returns the same registry object within that Luau execution environment.

## Behavior

Each invocation owns its own ModuleScript export cache. Registering a ModuleScript does **not** immediately call `require`; it happens when that path is first retrieved with [`Get`](../../registry/get/). Passing a plain value returns it directly on lookup, including `false`.

## See also

[`Resolvable<Entries>`](../../types/resolvable/) and [registrations and editor setup](../../../configuration/).

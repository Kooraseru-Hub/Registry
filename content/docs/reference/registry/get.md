---
title: registry:Get(path)
description: Read a registered value and report whether the lookup succeeded.
sidebar:
  label: Get(path)
---

Resolves one exact registration path. ModuleScripts are required on demand and successful exports are cached.

## Signature

```luau
Get(self: Registry<Path>, path: Path): (unknown, boolean)
```

Call as `registry:Get(path)`; the colon supplies `self`.

## Parameters

| Parameter | Type | Description |
| --- | --- | --- |
| `path` | `Path` | An existing key of the entries passed to `Register`. |

## Returns

| Position | Type | Description |
| --- | --- | --- |
| First | `unknown` | The registered value or ModuleScript export on success; an error message on failure. |
| Second | `boolean` | `true` for success; `false` for a missing path or failed ModuleScript load. |

A successfully registered `false` value returns `false, true`. Always check the second return value, not the truthiness of the first.

## Example

```luau
--!strict
const registry = require("@game/ReplicatedStorage/Registrations")

const result, ok = registry:Get("Game/Settings")
if not ok then
    warn(result)
    return
end

if type(result) == "table" then
    print(result)
end
```

## Caching and invalidation

- On the first lookup of a ModuleScript, Registry calls `require` inside `xpcall`.
- A successful export is cached by path and ModuleScript identity.
- A subsequent lookup of the same path with the same ModuleScript returns the cached export.
- If the registration entry is replaced, the previous cached export for that path is discarded on lookup.
- Plain registered values are returned directly, rather than cached by Registry.
- Registry does not cache failed loads. Roblox controls the underlying behavior of later `require` attempts.

## Errors

An absent key, including a key whose value has become `nil`, produces `"Unknown Registry path: ..."` with a `false` success flag. When a ModuleScript fails to load, the returned message contains the Registry path, the ModuleScript's full name, and an available traceback.

## Type checking

`Path` constrains **which names are legal**. The return value remains `unknown`; the current implementation does not connect each key to its registered value's static type.

## See also

[`Register(entries)`](../../functions/register/), [`Registry<Path>`](../../types/registry/), and [lookup results and errors](../../../learn/lookup-results/).

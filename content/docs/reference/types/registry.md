---
title: Registry<Path>
description: Public Luau type for a Registry object.
sidebar:
  label: Registry<Path>
---

The returned interface of [`Registry.Register`](../../functions/register/). `Path` is the type accepted by `Get`.

## Definition

```luau
export type Registry<Path> = {
    read Get: (self: Registry<Path>, path: Path) -> (unknown, boolean),
}
```

The `read` modifier describes the method member as read-only. At runtime, `Register` returns a frozen table containing `Get`.

## Type parameters

| Name | Description |
| --- | --- |
| `Path` | The allowed lookup keys, generally `Resolvable<Entries>`. |

## Methods

[`Get(path)`](../../registry/get/) resolves an exact path and returns `(unknown, boolean)`.

## Example

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

const entries = { ["UI/Theme"] = "dark" }
const registry = Registry.Register(entries)

const value, ok = registry:Get("UI/Theme")
```

There are no public properties or events on this type. The object is a Luau table, not a Roblox `Instance`.

## See also

[`Resolvable<Entries>`](../resolvable/) and [typed paths](../../../configuration/).

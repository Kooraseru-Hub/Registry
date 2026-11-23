---
title: Resolvable<Entries>
description: Derive valid lookup path types from registration keys.
sidebar:
  label: Resolvable<Entries>
---

`Resolvable` is an exported type alias used by `Register` to constrain the keys that can be passed to `Get`.

## Definition

```luau
export type Resolvable<Entries> = keyof<Entries>
```

## Type parameters

| Name | Description |
| --- | --- |
| `Entries` | The registration table type whose keys form the path type. |

## Example

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

const registry = Registry.Register({
    ["Data/Score"] = 0,
    ["Data/Label"] = "Ready",
})

registry:Get("Data/Score") -- valid
-- registry:Get("Data/Missing") -- type error with known literal keys
```

Using a broad dictionary type such as `{ [string]: unknown }` instead of a table with known literal keys reduces the precision of autocomplete and static path checking.

`Resolvable` describes legal keys, not the type of each key's result. [`Get`](../../registry/get/) returns `unknown` in every case.

## See also

[`Register(entries)`](../../functions/register/) and [registrations and editor setup](../../../configuration/).

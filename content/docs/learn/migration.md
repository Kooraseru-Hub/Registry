---
title: Migrating from the lifecycle API
description: Move legacy lifecycle registrations to the current Register and Get API.
---

The current Registry implementation exposes `Register` and `Get` only. It does not manage application startup, teardown, or service lifecycles.

## Create one shared registration

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

return Registry.Register({
    ["Game/Settings"] = script.Parent.Settings,
})
```

## Replace lookups

Import the shared registration ModuleScript and use `registry:Get("Game/Settings")`. Check the success flag and narrow the returned `unknown` value before use.

## Keep lifecycle logic in your application

Any initialization sequence, dependencies between services, and teardown must be managed by application code. Registry lazily loads ModuleScripts only; it does not call an initialization method on their exports.

See [the reference](../../reference/) for the supported API and [lookup results and errors](../lookup-results/) for behavior changes to account for.

---
title: Lookup results and errors
description: Handle Registry success flags, ModuleScript failures, and cache changes.
---

Registry uses an explicit success flag rather than raising a lookup error to callers.

## Handle both return values

```luau
const value, ok = registry:Get("Game/Settings")
if not ok then
    warn(value)
    return
end
```

The first result may legitimately be `false`, `0`, or an empty string. Do not write `if value then` to check whether lookup succeeded.

## Missing paths

A missing or `nil` entry returns an error string and `false`. Exact path matching is case-sensitive. `UI/Theme` is unrelated to `ui/theme`.

The Luau type system can catch many invalid *literal* path names, but it cannot guarantee that the runtime entry table has not been mutated.

## Failed modules

ModuleScript loads run under `xpcall`. A failure returns a message containing the Registry path, full ModuleScript name, and available traceback, followed by `false`.

Registry itself does not cache failed exports. Roblox may still control how a subsequent `require` behaves after a failure.

## Cache boundaries

A registry's successful ModuleScript cache belongs to that registry object. It is not a process-wide cache shared by every `Register` call.

A replaced ModuleScript entry invalidates the Registry cached export for that path on its next lookup. Requiring the same ModuleScript may also interact with Roblox's own per-environment `require` caching.

Plain values do not enter Registry's ModuleScript cache.

## Return type

The return type is `unknown`, even on success. Narrow it before dereferencing or calling. A valid path does not automatically imply the return type of its registered value.

For exact behavior and signatures, see [`Get(path)`](../reference/registry/get/).

---
title: API reference
description: Registry registration, typed lookup, cache behavior, and failures.
slug: api
sidebar:
  order: 4
---

## Registry.Register(entries)

Returns a registry for the supplied table. Use string paths for keys and either ModuleScript instances or values as entries. The inferred path type is the union of the table's known keys.

## registry:Get(path)

Returns `value, true` for a successful lookup and `message, false` when a path is missing or a ModuleScript fails to load. Check the success flag before using the result. The result is typed as `unknown`, so narrow it before accessing fields or calling it.

ModuleScripts are required on first lookup. Registry caches successful exports by path and ModuleScript identity. It returns plain registered values directly, including `false`. Registry does not cache a failed load, though Roblox controls whether the underlying `require` can load a module again. A loader error message includes the Registry path, full ModuleScript name, and available traceback.

## Migrating from the lifecycle API

Create a shared registration with `Registry.Register` and update consumers to import it and check the success flag from `Get`. Keep initialization, startup order, and teardown in your application code.

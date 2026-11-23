---
title: Registry
description: Typed, on-demand ModuleScript lookup for Roblox Luau.
sidebar:
  label: Overview
---

Registry lets Roblox scripts share named values and ModuleScripts through a registration table. Call `Register` once to define valid lookup paths, then import that registry and use `Get` wherever you need a value.

The registry loads ModuleScripts on their first lookup, caches successful exports, and returns ordinary registered values without requiring them.

## Start here

[Getting started](./getting-started/) walks through installation and the first lookup in Studio. [Registrations and editor setup](./configuration/) covers path naming, shared tables, and the editor fixture.

## API reference

The [reference overview](./reference/) lists every public function and type, following the summary-and-member format of Roblox's Creator Hub.

- [`Registry.Register(entries)`](./reference/functions/register/) constructs a registry.
- [`registry:Get(path)`](./reference/registry/get/) resolves a registered path.
- [`Registry<Path>`](./reference/types/registry/) describes the returned registry object.
- [`Resolvable<Entries>`](./reference/types/resolvable/) derives valid paths from registration keys.

## Behavior and measurement

Read [lookup results and errors](./learn/lookup-results/) for failure handling and caching, or [tests and benchmarks](./benchmarks/) for the repository's Studio suites.

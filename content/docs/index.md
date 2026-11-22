---
title: Registry
description: Shared typed module lookup for Roblox Luau.
sidebar:
  order: 1
  label: Overview
---

Registry gives Roblox scripts a shared set of named values and ModuleScripts. Declare your paths in a registration module, then call `Get` from any script that imports it. Luau infers the valid paths from the registration keys, and Registry loads each ModuleScript on demand.

## Get started

[Install Registry and make your first lookup](./getting-started/) in Roblox Studio. The guide walks through registering a ModuleScript and reading its export from another script.

## Explore Registry

- [Registrations and editor setup](./configuration/) explains how to choose lookup paths and set up editor completion.
- [API reference](./api/) documents return values, caching, and errors.
- [Tests and benchmarks](./benchmarks/) shows how to reproduce the Studio checks and measure first loads and cached lookups.

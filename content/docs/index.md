---
title: Registry
description: Shared typed module lookup for Roblox Luau.
---

Registry gives Roblox scripts a shared set of named values and ModuleScripts. Declare your paths in a registration module, then call `Get` from any script that imports it. Luau infers the valid paths from the registration keys, and Registry loads each ModuleScript on demand.

- [Install Registry and make your first lookup](./getting-started/)
- [Organize registrations and configure editor completion](./configuration/)
- [Read the API and error behavior](./api/)
- [Reproduce the Studio tests and benchmarks](./benchmarks/)

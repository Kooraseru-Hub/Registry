## Registry 1.0.0

This release captures Registry as a path-based module manager for Roblox Luau. It gives a Roblox experience one place to register ModuleScripts or loaded module tables, find them by path, and coordinate their lifecycle.

- **Registration and lookup.** Register modules under hierarchical paths and look them up by path, alias, or registered instance.
- **Lifecycle.** Run Setup, Init, and Start with category and priority ordering. Destroy runs in reverse initialization order and cleans up tracked resources for initialized modules.
- **Dependency diagnostics.** Declare dependencies to get warnings for missing registrations and cycles. Hooks and inspection helpers expose lifecycle errors and registry state.
- **Distribution.** This was the first release built with the shared CI Template. The original module tree and its CC0 license are in `Registry.zip`.

## Contributors

- [@Kooraseru](https://github.com/Kooraseru)
- [@NeverSimplified](https://github.com/NeverSimplified)
- [@ChristopherCAaaaaa](https://github.com/ChristopherCAaaaaa)

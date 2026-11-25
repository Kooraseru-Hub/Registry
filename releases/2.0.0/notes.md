## Registry 2.0.0

Registry is now a small typed lookup library, not a lifecycle framework.

- `Registry.Register(entries)` creates a shared registry with inferred lookup paths.
- `registry:Get(path)` loads ModuleScripts on demand, caches successful results and returns a value or error with a success flag.
- Plain values can also be registered. Export types remain `unknown`; narrow before accessing members.
- Lifecycle management, dependency ordering, hooks and cleanup have been removed.

Download `Registry.rbxm` and import the ModuleScript in Studio, or use `Registry.zip` / the Luau source directly. Prefer ReplicatedFirst for early client bootstrapping; ReplicatedStorage is suitable for ordinary shared modules.

[Documentation](https://kooraseru-hub.github.io/Registry/)

## Contributors

- [@Kooraseru](https://github.com/Kooraseru)

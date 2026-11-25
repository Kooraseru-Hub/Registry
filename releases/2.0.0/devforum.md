## Registry 2.0.0

so uh... this announcement is a little (very) late, but hey, Registry is finally a registry! turns out a library called Registry didn't need to be an entire lifecycle system.

#### what's changed?

the library has been rewritten around a much smaller API, with the focus being on registering and retrieving values rather than managing the lifecycle of your application.

1. `Registry.Register(entries)` creates a shared registry with inferred lookup paths.
2. `registry:Get(path)` loads ModuleScripts on demand, caches successful results, and returns the value or error alongside a success flag.
3. you can register plain values too, not just ModuleScripts. exported values are typed as `unknown`, so you'll need to narrow the type before accessing its members.

#### what's gone?

lifecycle management, dependency ordering, hooks, and cleanup are no longer part of Registry. if you're migrating from 1.x, this is a breaking change; those responsibilities are now left to your application.

you can grab the `Registry.rbxm` from the release and import it into Studio, or use the ZIP / Luau source directly.

[documentation](https://kooraseru-hub.github.io/Registry/)

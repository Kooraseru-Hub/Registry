so uh... a super-duper late announcement, but Registry 2.0.0 is out! after some rather questionable scope creep, Registry is finally just a registry.

#### what's changed?

- rewritten around `Registry.Register(entries)` and `registry:Get(path)`.
- inferred lookup paths and on-demand ModuleScript loading with caching.
- support for registering plain values alongside ModuleScripts.
- removed lifecycle management, dependency ordering, hooks and cleanup.

this is a breaking change for anyone using 1.x.

[documentation](https://kooraseru-hub.github.io/Registry/)

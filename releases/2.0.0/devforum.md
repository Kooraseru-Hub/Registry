so uh... remember when I said to give me 3-4 hours?

:sob:

anywho, Registry v2.0.0 is out! after somehow turning a registry into an entire lifecycle framework, <mark>Registry is now just a registry.</mark>

#### what's changed?

- removed the `Server`, `Client` and `Shared` context declarations; Registry no longer cares what context you're running it in.
- failed `require()` calls are now caught using `xpcall`, returning the error and traceback instead of throwing.
- ModuleScripts are loaded on demand rather than during registration.
- lookup paths are now inferred by Luau, providing autocomplete and type checking.
- you can register pretty much any value, not just modules.
- removed the reliance on `_G.Registry`.
- removed lifecycle management, dependency ordering, hooks and automatic cleanup.

<small>in other words, I fixed a decent number of problems by removing the things causing them. revolutionary stuff, I know.</small>

[documentation](https://kooraseru-hub.github.io/Registry/) | [migration guide](https://kooraseru-hub.github.io/Registry/learn/migration/)

<div align="center">

# Registry

**Path-based module management for Roblox Luau.**

</div>

## Workspace

- source/Registry.luau is the library.
- 	ests/registry contains the Registry tests and their Studio place.

## Configuration

| Tool | Editable config |
| --- | --- |
| TypeScript | [tsconfig.json](.vscode/config/typescript/tsconfig.json) |
| Luau | [.luaurc](.vscode/config/luau/.luaurc) |
| act | [actrc](.vscode/config/act/actrc) |

Dependency setup generates ignored root files for tools that discover their config at the workspace root. Edit the files linked above.

## Rule checks

Install Template's pinned tools with `node dependencies/packages/core/dependencyLoader/index.ts`. Run `node dependencies/packages/checks/preflightChecker/index.ts --rules` to see the repository rules findings, or `node ci/code-review.cjs` to run the inherited review checks.

## Quick start

Place `Registry.luau` in ReplicatedStorage as a ModuleScript named Registry. In a shared Registrations ModuleScript, return the registry you construct.

```luau
const Registry = require("@game/ReplicatedStorage/Registry")
return Registry.Register({ ["Data/Scalar"] = script.Parent.Scalar })
```

Consumers require Registrations and call `registry:Get("Data/Scalar")`. The registration keys supply the allowed lookup paths. ModuleScripts load on first lookup, and successful results are cached.

This revision replaces the previous lifecycle API. Callers that use the old initialization, startup, or teardown methods need to migrate.

## Lookup failures

`Get(path)` returns `value, true` on success or `message, false` when the path is missing or its ModuleScript fails to load. Load failures include the Registry path, ModuleScript name, and available traceback.

## Registry tests

Registry path inference uses the new Luau type solver. In Studio, set **Workspace â†’ Scripting â†’ UseNewLuauTypeSolver** to **Enabled** in strict-mode places.

Open 	ests/registry/Registry.rbxlx in Studio. ReplicatedStorage.tests.registry.Consumer.Run() checks that a separate consumer can look up the entries declared in Registrations.

[Benchmark results and reproduction steps](tests/registry/Benchmark/README.md)

For VS Code, run `node .vscode/config/luau/generate-sourcemap.cjs` from the repository root. Run it again after adding, moving, or renaming scripts. The generated root `sourcemap.json` is ignored by Git.

[Generated fixtures and local Studio testing](tests/registry/Studio/README.md)

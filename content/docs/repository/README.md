<div align="center">
  <img src="content/images/banner.png" alt="Registry">
  <p><strong>Typed module lookup for Roblox Luau</strong></p>
</div>

Registry lets scripts share a named set of values and ModuleScripts. Register entries once, then look them up from any script that imports the registration. Luau infers the valid paths from the registration keys. ModuleScripts load on demand, and successful exports are cached.

## Installation

Copy `source/Registry.luau` into a ModuleScript named `Registry` in `ReplicatedStorage`. Enable the new Luau type solver under **Workspace > Scripting > UseNewLuauTypeSolver**.

## Quick start

In `ReplicatedStorage`, create a ModuleScript named `Settings` that returns your settings. Create a sibling ModuleScript named `Registrations` with the following source.

```luau
--!strict
const Registry = require("@game/ReplicatedStorage/Registry")

return Registry.Register({
    ["Game/Settings"] = script.Parent.Settings,
})
```

From a separate script, import the shared registration and look up the entry.

```luau
--!strict
const registry = require("@game/ReplicatedStorage/Registrations")
const settings, ok = registry:Get("Game/Settings")

if ok then
    print(settings)
else
    warn(settings)
end
```

`Get` returns `value, true` on success or `message, false` when a path is missing or a ModuleScript fails to load. The result is typed as `unknown`. Narrow it before accessing its fields.

## More information

- [Documentation and API reference](https://kooraseru-hub.github.io/Registry/)
- [Benchmark methodology and raw results](https://github.com/Kooraseru-Hub/Registry/tree/source/tests/registry/Benchmark)
- [Contributing](https://github.com/Kooraseru-Hub/Registry/tree/source)
- [License](LICENSE)

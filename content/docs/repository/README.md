<div align="center">
  <img src="content/images/banner.png" alt="Registry">
  <p><strong>Typed module lookup for Roblox Luau</strong></p>
</div>

<div align="center">
  <!-- Sponsor -->
  <a href="https://github.com/sponsors/Kooraseru"><img alt="Sponsor" src="https://shieldcn.dev/badge/sponsor-plz%20im%20broke.svg?variant=secondary&amp;logo=githubsponsors&amp;gradient=a64d92%2C+7955c7"></a>
  <!-- Stars -->
  <a href="https://github.com/kooraseru-hub/registry"><img alt="Stars" src="https://shieldcn.dev/github/kooraseru-hub/registry/stars.svg?variant=secondary&amp;logo=lu%3AStar&amp;label=my+ego+has+been+validated+by&amp;gradient=b27b28%2C+bd623d"></a>
  <!-- Forks -->
  <a href="https://github.com/Kooraseru-Hub/registry/forks"><img alt="Forks" src="https://shieldcn.dev/github/Kooraseru-Hub/registry/forks.svg?variant=secondary&amp;logo=ri%3APiGitFork&amp;label=stolen+by&amp;gradient=278c82%2C+376ca8"></a>
  <!-- USA! USA! USA! -->
  <img alt="Fact checked by true American patriots" src="https://shieldcn.dev/badge/this%20repo%20has%20been%20facted%20checked%20by%20TRUE%20american%20patriots-abcde3.svg?variant=secondary&amp;logo=ri%3AFaFlagUsa&amp;gradient=bd4854%2C+3f5da8">
</div>

---

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

## Why use Registry?

Use Registry when several scripts need a shared set of named modules. Consumers get autocomplete for registered names, and moving or swapping a ModuleScript takes one edit in the registration table. Modules load on first use, and callers can handle a failed load through the success flag.

For a dependency you already know and can load once, keep a direct `require` in a local binding. It gives Luau the module's export type and avoids doing a lookup on each use.

## Benchmarks

Roblox Studio measurements show median latency per call across module counts and initialization workloads.

| | First load | Repeated lookup |
| --- | --- | --- |
| Direct require | ![Direct require first-load heatmap](tests/registry/Benchmark/Results/require-cold-matrix.png) | ![Direct require repeated lookup heatmap](tests/registry/Benchmark/Results/require-warm-matrix.png) |
| Registry | ![Registry first-load heatmap](tests/registry/Benchmark/Results/registry-cold-matrix.png) | ![Registry repeated lookup heatmap](tests/registry/Benchmark/Results/registry-warm-matrix.png) |

## More information

<div align="center">
  <!-- Documentation -->
  <a href="https://kooraseru-hub.github.io/Registry/"><img alt="Documentation" src="https://shieldcn.dev/badge/documentation-its%20a%20single%20script%20idfk%20why%20you%20need%20this%20bro.svg?variant=secondary&amp;logo=outline&amp;labelColor=000000&amp;gradient=2c6cbc%2C+195dba"></a>
  <!-- Benchmark -->
  <a href="https://github.com/Kooraseru-Hub/Registry/tree/source/tests/registry/Benchmark"><img alt="How to benchmark" src="https://shieldcn.dev/badge/how%20to%20bench%20Mark.svg?variant=secondary&amp;logo=speedtest&amp;labelColor=000000&amp;gradient=ffa585%2C+f68080"></a>
  <!-- Contribute -->
  <a href="CONTRIBUTING.md"><img alt="Contribute" src="https://shieldcn.dev/badge/contribute-plz.svg?variant=secondary&amp;logo=lu%3AHandHelping&amp;labelColor=000000&amp;gradient=5da92f%2C+9bd46a"></a>
  <!-- License -->
  <a href="LICENSE"><img alt="CC0 1.0 license" src="https://shieldcn.dev/badge/license-CC0%201.0.svg?variant=secondary&amp;split=true&amp;logo=unlicense"></a>
</div>

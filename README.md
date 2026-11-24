<div align="center">
  <img src="https://raw.githubusercontent.com/Kooraseru-Hub/Registry/source/content/images/banner.png" alt="Registry">
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

Choose one installation method:

1. **Studio model (recommended):** download `Registry.rbxm` from the [2.0.0 release](https://github.com/Kooraseru-Hub/Registry/releases/tag/2.0.0). Import the model into Studio and place the resulting `Registry` ModuleScript under `ReplicatedFirst`.
2. **Source:** copy [`source/Registry.luau`](https://github.com/Kooraseru-Hub/Registry/blob/main/source/Registry.luau) (also included in `Registry.zip`) into a ModuleScript named `Registry` under `ReplicatedFirst`.

Use `ReplicatedFirst` for early client bootstrappers, or `ReplicatedStorage` for ordinary shared code; adjust the require path accordingly. Early replication of Registry does not make its registered dependencies replicate earlier. Wait for any dependencies outside ReplicatedFirst when necessary.

Enable the new Luau type solver under **Workspace > Scripting > UseNewLuauTypeSolver**.

## Quick start

In `ReplicatedStorage`, create a ModuleScript named `Settings` that returns your settings. Create a sibling ModuleScript named `Registrations` with the following source.

```luau
--!strict
const Registry = require("@game/ReplicatedFirst/Registry")

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

The benchmarks compare direct `require` and `Registry:Get` for first loads and repeated lookups. Each cell shows median latency per operation.

<div align="center">

<p align="center">
  <img width="49%" src="benchmarks/require-cold-matrix.svg" alt="Direct require first loads">
  <img width="49%" src="benchmarks/require-warm-matrix.svg" alt="Direct require cached lookups">
</p>

<p align="center">
  <img width="49%" src="benchmarks/registry-cold-matrix.svg" alt="Registry first loads">
  <img width="49%" src="benchmarks/registry-warm-matrix.svg" alt="Registry cached lookups">
</p>

Measured <time datetime="2026-11-24T03:25:03Z">2026-11-24 03:25:03 UTC</time><br>
Roblox Open Cloud<br>
Test place version <code>603</code><br>
Source commit <code>9526ea1ea7b290800d6784af3fcb68f01fb6354b</code>

</div>

<details>
<summary>Workloads and measurement details</summary>

Each phase is a 30 × 30 matrix. In the first-load phase, row `r` uses `floor(16 × 1.16^(r − 1))` calls, each to a distinct ModuleScript. Columns combine arithmetic, table writes, or mixed initialization with ten work levels from 0 to 512 steps. Each method receives its own fresh clones for every trial. In the repeated-lookup phase, rows use `floor(256 × 1.33^(r − 1))` calls and columns combine ten registry sizes from 1 to 2,048 modules with sequential access, a shuffle seeded with 42, or a hot subset containing the first eighth of the modules, with a minimum of one. Both methods run an untimed warmup before sampling.

Each cell records four paired trials. Both methods walk the same index sequence, and the order alternates so each method goes first twice. The harness uses `os.clock()` around the full lookup loop, including index traversal and checksum accumulation. Clone setup, registration, warmup, and checksum comparison happen outside the timer. The harness rejects unequal or zero checksums. For each method it divides elapsed seconds by the operation count and takes the median of the four values. Both heatmaps in a phase share a logarithmic color scale.

To reproduce, check out the revision of interest and run **Registry: Benchmark and Build** with Ctrl+Shift+B on Windows. It generates a fresh test place from the checkout and starts a new Studio process. For a revision comparison, use the same machine, Studio version, power settings, and workload. Close competing workloads and repeat both revisions to see how much timings vary between runs. Keep the raw `matrix-samples.csv` alongside the charts so you can recompute each median and inspect the paired trials. Four pairs per cell describe the run. Repeat the experiment before treating small differences as meaningful.


</details>

## More information

<div align="center">
  <!-- Documentation -->
  <a href="https://kooraseru-hub.github.io/Registry/"><img alt="Documentation" src="https://shieldcn.dev/badge/documentation-its%20a%20single%20script%20idfk%20why%20you%20need%20this%20bro.svg?variant=secondary&amp;logo=outline&amp;labelColor=000000&amp;gradient=2c6cbc%2C+195dba"></a>
  <!-- Benchmark -->
  <a href="https://github.com/Kooraseru-Hub/Registry/tree/source/tests/registry/benchmarks"><img alt="How to benchmark" src="https://shieldcn.dev/badge/how%20to%20bench%20Mark.svg?variant=secondary&amp;logo=speedtest&amp;labelColor=000000&amp;gradient=ffa585%2C+f68080"></a>
  <!-- Contribute -->
  <a href="CONTRIBUTING.md"><img alt="Contribute" src="https://shieldcn.dev/badge/contribute-plz.svg?variant=secondary&amp;logo=lu%3AHandHelping&amp;labelColor=000000&amp;gradient=5da92f%2C+9bd46a"></a>
  <!-- License -->
  <a href="LICENSE"><img alt="CC0 1.0 license" src="https://shieldcn.dev/badge/license-CC0%201.0.svg?variant=secondary&amp;split=true&amp;logo=unlicense"></a>
</div>

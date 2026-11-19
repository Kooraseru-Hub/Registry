# Registry

**Path-based module management for Roblox Luau.**

[![Latest release](https://shieldcn.dev/github/release/Kooraseru-Hub/Registry.svg)](https://github.com/Kooraseru-Hub/Registry/releases/latest)
[![GitHub Actions](https://shieldcn.dev/github/ci/Kooraseru-Hub/Registry.svg)](https://github.com/Kooraseru-Hub/Registry/actions)
[![CC0 1.0](https://shieldcn.dev/badge/license-CC0%201.0-blue.svg)](LICENSE)

## Install

1. Download `Registry.zip` from [GitHub Releases](https://github.com/Kooraseru-Hub/Registry/releases) or copy `source/Registry` from [main](https://github.com/Kooraseru-Hub/Registry/tree/main).
2. Import `Registry` as a ModuleScript tree. Each `init.luau` is the ModuleScript for its folder.
3. Place it in `ReplicatedStorage` for shared code or `ServerScriptService` for server-only code.

## Quick start

With `Registry` in `ReplicatedStorage`, a script can register a module and run its lifecycle.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Registry)

Registry:Register("Services/Data", require(script.Parent.Data))
Registry:RunLifecycle()
```

Use `Registry:Get("Services/Data")` to look up the registered module. Registry supports dependencies, lifecycle hooks, and cleanup with Maid.

## Contribute

Open a pull request against [source](https://github.com/Kooraseru-Hub/Registry/tree/source) or [report an issue](https://github.com/Kooraseru-Hub/Registry/issues/new/choose). Registry is dedicated to the public domain under [CC0 1.0](LICENSE).

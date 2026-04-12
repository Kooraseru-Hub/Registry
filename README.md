<h1 align="center">Registry</h1>

<p align="center">
  <strong>A lightweight, type-safe module management system for Luau</strong><br>
  Streamline module initialization, eliminate circular dependencies, and optimize your codebase with path-based organization and dependency resolution.
</p>

<div align="center">
    <a href="https://github.com/Kooraseru-Hub/Registry">
        <img src="https://img.shields.io/badge/Source%20Code-00A2FF?style=for-the-badge&logo=github&logoColor=white"></a>
    <a href="https://create.roblox.com/store/asset/83203149398671/Registry">
        <img src="https://img.shields.io/badge/Download-000000?style=for-the-badge&logo=data:image/svg%2bxml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAyOC40LjEsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjxzdmcgdmVyc2lvbj0iMS4xIiBpZD0iUm9ibG94Xy1fSWNvbl94MkNfXzIwMjUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiDQoJIHg9IjBweCIgeT0iMHB4IiB2aWV3Qm94PSIwIDAgNTEyIDUxMiIgc3R5bGU9ImVuYWJsZS1iYWNrZ3JvdW5kOm5ldyAwIDAgNTEyIDUxMjsiIHhtbDpzcGFjZT0icHJlc2VydmUiPg0KPHN0eWxlIHR5cGU9InRleHQvY3NzIj4NCgkuc3Qwe2ZpbGw6I0ZGRkZGRjt9DQo8L3N0eWxlPg0KPGcgaWQ9IlN0dWRpbyI+DQoJPHBhdGggaWQ9IkJHIiBkPSJNNDE5LjgsNTEySDkyLjJDNDEuMyw1MTIsMCw0NzAuNywwLDQxOS44VjkyLjJDMCw0MS4zLDQxLjMsMCw5Mi4yLDBoMzI3LjVDNDcwLjcsMCw1MTIsNDEuMyw1MTIsOTIuMnYzMjcuNQ0KCQlDNTEyLDQ3MC43LDQ3MC43LDUxMiw0MTkuOCw1MTJ6Ii8+DQoJPGcgaWQ9Ik9fQmx4XzAwMDAwMTMxMzYzNjI4MTcwMzcyNzEwMjkwMDAwMDA0NDY0ODg5NzU4MTkzNTU4Njc0XyI+DQoJCTxwb2x5Z29uIGNsYXNzPSJzdDAiIHBvaW50cz0iMzk5LjksMjk0LjYgMjk2LjIsMjY2LjggMjg1LjQsMzA3IDEwMS40LDI1Ny43IDczLjYsMzYxLjMgMzYxLjMsNDM4LjQgMzg5LjEsMzM0LjggMzg5LjEsMzM0LjggCQkNCgkJCSIvPg0KCQk8cG9seWdvbiBjbGFzcz0ic3QwIiBwb2ludHM9IjQzOC40LDE1MC43IDE1MC43LDczLjYgMTEyLjEsMjE3LjQgMjE1LjgsMjQ1LjIgMjI2LjYsMjA1IDQxMC42LDI1NC4zIAkJIi8+DQoJPC9nPg0KPC9nPg0KPC9zdmc+DQo="></a>
    <a href="LICENSE">
        <img src="https://img.shields.io/badge/License-CC0%201.0-blue?style=for-the-badge"></a>
</div>

---

## Table of Contents

- [Why Registry?](#why-registry)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Benefits Over Traditional Requiring](#benefits-over-traditional-requiring)
- [Best Practices](#best-practices)

---

## Why Registry?

Traditional module management in Luau involves scattered `require()` calls throughout your codebase, leading to:

- [ ] **Circular dependency nightmares**
- [ ] **Tight coupling** between modules
- [ ] **No control over initialization order**
- [ ] **Repeated require statements** causing clutter
- [ ] **Hard-coded file paths** that break when restructuring
- [ ] **Difficult testing** with dependencies baked in

**Registry** solves these problems by centralizing module management with path-based registration, dependency injection, and a clean lifecycle system.

---

## Features

- [x] **Path-based registration** with filesystem-like module organization
- [x] **Dependency management** with automatic cycle detection
- [x] **Full lifecycle control** (Setup → Init → Start → Destroy)
- [x] **Category-based ordering** with priority system for fine-grained control
- [x] **Dependency injection** through the registry pattern
- [x] **Zero circular dependencies** - modules get references through registry
- [x] **Advanced path resolution** with aliases, relative paths, and @prefixes
- [x] **Type-safe** with full Luau strict mode support
- [x] **Hooks system** for monitoring and extending behavior
- [x] **Error tracking** with comprehensive debugging information
- [x] **Maid-based cleanup** for automatic resource management
- [x] **Inspection tools** for monitoring registry state
- [x] **Native compilation** optimized (`--!native`, `--!optimize 2`)

---

## Installation

1. Download `Registry` from this repository
2. Place it in `ReplicatedStorage` (for shared access) or your project folder
3. Require it once in your main script

```lua
local Registry = require("@self/Registry")
```

---

## Quick Start

### Basic Setup

```lua
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require("@self/Registry")

Registry:Register("Services/DataService", require("./Services/DataService"))
Registry:Register("Services/PlayerService", require("./Services/PlayerService"))
Registry:Register("Systems/CombatSystem", require("./Systems/CombatSystem"))

Registry:SetStartOrder({"Core", "Services", "Systems"})

Registry:InitAll()
Registry:StartAll()
```

### Creating a Module

```lua
-- Services/DataService.lua
--!strict

local DataService = {
    Category = "Services",
    Priority = 10,
}

function DataService:Setup()
    print("DataService setup")
end

function DataService:Init(registry, path)
    print("DataService initializing at:", path)
    self.PlayerService = registry:Get("Services/PlayerService")
end

function DataService:Start()
    print("DataService started!")
end

function DataService:Destroy(registry)
    print("DataService destroyed")
end

function DataService:SavePlayer(player)
end

return DataService
```

---

## API Reference

### Constructor & Core Methods

<details>
<summary><code>Registry:Register(path: string, module: ModuleScript | Module)</code></summary>

Registers a module at the specified absolute path.

**Parameters:**
- `path`: Absolute path (e.g., `"Services/PlayerService"`)
- `module`: ModuleScript instance or pre-loaded module table

**Example:**
```lua
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require("@self/Registry")

Registry:Register("Services/Database", DatabaseModule)
Registry:Register("Controllers/PlayerController", require("./Controllers/PlayerController"))
```
</details>

---

<details>
<summary><code>Registry:Get(target: string | ModuleScript | Module, caller?: Module): Module</code></summary>

Resolves and returns a registered module.

**Parameters:**
- `target`: Path string (absolute, alias, or relative) or Instance
- `caller`: Optional: required for relative path resolution

**Returns:** The resolved module table.

**Example:**
```lua
-- ReplicatedStorage/Shared/Bootstrap.luau
--!strict

local Registry = require("@self/Registry")

local dataService = Registry:Get("Services/DataService")

Registry:RegisterAlias("shared", "ReplicatedStorage/Shared")

local logger = Registry:Get("@shared/Utils/Logger")
local config = Registry:Get("@game/ReplicatedStorage/Config")
```
</details>

---

<details>
<summary><code>Registry:RegisterAlias(alias: string, path: string)</code></summary>

Creates a custom alias for path resolution.

**Parameters:**
- `alias`: Alias name (without @ prefix or slashes)
- `path`: Absolute path the alias expands to

**Example:**
```lua
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require("@self/Registry")

Registry:RegisterAlias("shared", "ReplicatedStorage/Shared")
Registry:RegisterAlias("server", "ServerScriptService/Server")

local helper = Registry:Get("@shared/Utils/Helper")
local logger = Registry:Get("@server/Utils/Logger")
```
</details>

<details>
<summary>Alias Demo</summary>

Use aliases when you want a stable import target that does not force every consumer to know the full absolute path.

```lua
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require("@self/Registry")

Registry:Register("ReplicatedStorage/Shared/Utils/Logger", require("./Shared/Utils/Logger"))
Registry:Register("ReplicatedStorage/Shared/Config/GameConfig", require("./Shared/Config/GameConfig"))

Registry:RegisterAlias("shared", "ReplicatedStorage/Shared")

local logger = Registry:Get("@shared/Utils/Logger")
local gameConfig = Registry:Get("@shared/Config/GameConfig")

print(logger, gameConfig)
```
</details>

---

### Lifecycle Methods

#### `Registry:RunLifecycle()`

Executes all lifecycle stages in order: Setup → Init → Start. Validates dependencies before running.

```lua
-- ServerScriptService/Main.server.lua
--!strict

Registry:RunLifecycle()
```

---

#### `Registry:SetupAll()`

Runs only the Setup stage on all modules.

```lua
-- ServerScriptService/Main.server.lua
--!strict

Registry:SetupAll()
```

---

#### `Registry:InitAll()`

Runs Setup and Init stages. Validates dependencies and reports cycles.

```lua
-- ServerScriptService/Main.server.lua
--!strict

Registry:InitAll()
```

---

#### `Registry:StartAll()`

Runs the Start stage on all modules in category order.

```lua
-- ServerScriptService/Main.server.lua
--!strict

Registry:StartAll()
```

---

#### `Registry:DestroyAll()`

Runs Destroy stage in reverse registration order, then flushes per-module Maids.

```lua
-- ServerScriptService/Main.server.lua
--!strict

Registry:DestroyAll()
```

---

#### `Registry:SetStartOrder(order: { string })`

Declares ordered categories that lifecycle stages execute in sequence.

**Parameters:**
- `order`: Array of category names defining execution order

**Example:**
```lua
-- ServerScriptService/Main.server.lua
--!strict

Registry:SetStartOrder({"Core", "Services", "Systems", "UI"})
```

---

### Utilities

#### `Registry:IsRegistered(path: string, caller?: Module): boolean`

Returns true if the given path resolves to a registered module.

```lua
if Registry:IsRegistered("Services/Database") then
    local db = Registry:Get("Services/Database")
end
```

---

#### `Registry:GetDescendants(path: string, caller?: Module): { Module }`

Returns all modules whose paths are descendants of the given path.

```lua
local controllers = Registry:GetDescendants("Controllers")
```

---

#### `Registry:GetByCategory(category: string): { Module }`

Returns all modules with the given category.

```lua
local systems = Registry:GetByCategory("Systems")
```

---

#### `Registry:On(event: HookEvent, callback: HookCallback): HookConnection`

Registers a hook to monitor and extend Registry behavior.

**Supported Events:**
- `"BeforeRegister"`: Before module registration
- `"AfterRegister"`: After module registration
- `"BeforeStage"`: Before each lifecycle stage
- `"AfterStage"`: After each lifecycle stage
- `"OnError"`: When a module errors during a stage

```lua
Registry:On("AfterRegister", function(path, module)
    print("Registered:", path)
end)

Registry:On("OnError", function(module, stage, error)
    warn("Error in", stage, "stage:", error)
end)
```

---

#### `Registry:GetErrors(): { [Module]: { ErrorRecord } }`

Returns error state for all modules.

```lua
local errors = Registry:GetErrors()
for module, records in pairs(errors) do
    for _, record in ipairs(records) do
        print(record.stage, "error:", record.error)
    end
end
```

---

#### `Registry:ListModules(): string`

Returns a human-readable listing of all registered modules with categories and status.

```lua
print(Registry:ListModules())
-- Output:
-- Services/Database (Services, Priority: 10) ✓
-- Services/PlayerService (Services, Priority: 20) ✗ [1 error]
-- Systems/Combat (Systems, Priority: 5) ✓
```

---

#### `Registry:Inspect(): InspectorSnapshot`

Returns a diagnostic snapshot of registry state.

```lua
local snapshot = Registry:Inspect()
print("Modules:", snapshot.moduleCount)
print("Categories:", snapshot.categoryCount)
print("Errors:", snapshot.errorCount)
```

---

#### `Registry:GetMaid(module: Module): Maid`

Returns the per-module Maid for automatic resource cleanup.

```lua
local maid = Registry:GetMaid(MyModule)
maid:Track(someConnection)
```

---

### Example 1: Server Setup with Ordered Initialization

```lua
-- ServerScriptService/Main.server.lua
local Registry = require("@self/Registry")

-- Core systems that others depend on
Registry:Register("Core/DataStore", require("./Core/DataStore"))
Registry:Register("Core/NetworkManager", require("./Core/NetworkManager"))

-- Services layer
Registry:Register("Services/PlayerService", require("./Services/PlayerService"))
Registry:Register("Services/InventoryService", require("./Services/InventoryService"))
Registry:Register("Services/ShopService", require("./Services/ShopService"))

-- Game systems
Registry:Register("Systems/CombatSystem", require("./Systems/CombatSystem"))
Registry:Register("Systems/QuestSystem", require("./Systems/QuestSystem"))

-- Set category order, then run the full lifecycle (Setup → Init → Start)
Registry:SetStartOrder({"Core", "Services", "Systems"})
Registry:RunLifecycle()

print("Server initialized successfully!")
```

---

### Example 2: Module with Dependencies

```lua
-- Services/ShopService.lua
local ShopService = {
    Category = "Services",
    Dependencies = {
        "Services/InventoryService",
        "Core/DataStore",
        "Core/NetworkManager",
    }
}

function ShopService:Init(registry, name)
    -- Get dependencies from registry (no require() needed!)
    self.InventoryService = registry:Get("Services/InventoryService")
    self.DataStore = registry:Get("Core/DataStore")
    self.NetworkManager = registry:Get("Core/NetworkManager")
    
    print(name, "initialized with dependencies")
end

function ShopService:Start()
    -- Set up remote events
    self.NetworkManager:RegisterRemote("PurchaseItem", function(player, itemId)
        self:PurchaseItem(player, itemId)
    end)
    
    print("ShopService started and listening for purchases")
end

function ShopService:PurchaseItem(player, itemId)
    -- Use dependencies without require()
    local success = self.InventoryService:AddItem(player, itemId)
    if success then
        self.DataStore:SaveInventory(player)
    end
    return success
end

return ShopService
```

---

### Example 3: Client Setup

```lua
-- StarterPlayer/StarterPlayerScripts/ClientMain.client.lua
local Registry = require("@self/Registry")

-- Register UI controllers
Registry:Register("UI/UIController", require("./UI/UIController"))
Registry:Register("UI/HUDController", require("./UI/HUDController"))
Registry:Register("UI/InventoryUI", require("./UI/InventoryUI"))

-- Register client systems
Registry:Register("Systems/InputHandler", require("./Systems/InputHandler"))
Registry:Register("Systems/CameraController", require("./Systems/CameraController"))
Registry:Register("Systems/SoundManager", require("./Systems/SoundManager"))

-- Set category order, then run the full lifecycle
Registry:SetStartOrder({"Systems", "UI"})
Registry:RunLifecycle()
```

---

### Example 4: Module Lifecycle

```lua
-- Example showing all lifecycle methods
local MyModule = {
    Category = "Systems",
    Priority = 50,
}

-- Optional: Early setup before any modules are initialized
function MyModule:Setup()
    print("Setup: Prepare module before initialization")
    self.config = {
        maxPlayers = 10,
        timeout = 30
    }
end

-- Optional: Called after all modules are registered
function MyModule:Init(registry, name)
    print("Init: Getting dependencies and setting up connections")
    self.playerService = registry:Get("Services/PlayerService")
    self.connections = {}
end

-- Optional: Called when module should begin active operation
function MyModule:Start()
    print("Start: Begin active operations")
    self.connections.playerAdded = game.Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
    end)
end

-- Optional: Called when module needs cleanup
function MyModule:Destroy()
    print("Destroy: Cleanup resources")
    for _, connection in pairs(self.connections) do
        connection:Disconnect()
    end
end

function MyModule:OnPlayerAdded(player)
    -- Custom logic
end

return MyModule
```

---

## Benefits Over Traditional Requiring

### ❌ Traditional Approach

```lua
-- Services/ShopService.lua
local InventoryService = require("../InventoryService")  -- Path dependency
local DataStore = require("../Core/DataStore")     -- Path dependency
local NetworkManager = require("@self/NetworkManager") -- Hard-coded path

local ShopService = {}

function ShopService:PurchaseItem(player, itemId)
    -- What if InventoryService also requires ShopService? CIRCULAR DEPENDENCY! ⚠️
    InventoryService:AddItem(player, itemId)
end

return ShopService
```

**Problems:**

- [ ] Hard-coded paths break when restructuring
- [ ] Circular dependencies cause runtime errors
- [ ] No control over initialization order
- [ ] Tight coupling makes testing difficult
- [ ] Repeated `require()` statements everywhere
- [ ] Dependency discovery is scattered throughout codebase

---

### ✅ Registry Approach

```lua
-- Services/ShopService.lua
local ShopService = {
    Dependencies = {
        "Services/InventoryService",
        "Core/DataStore",
        "Core/NetworkManager",
    }
}

function ShopService:Init(registry, name)
    -- Clean dependency injection - no paths, no circular dependencies!
    self.InventoryService = registry:Get("Services/InventoryService")
    self.DataStore = registry:Get("Core/DataStore")
    self.NetworkManager = registry:Get("Core/NetworkManager")
end

function ShopService:PurchaseItem(player, itemId)
    -- All dependencies are ready and safe to use
    self.InventoryService:AddItem(player, itemId)
end

return ShopService
```

**Advantages:**

- [x] No hard-coded paths - reference by name
- [x] Zero circular dependencies - Init happens after all modules are registered
- [x] Controlled initialization order with categories and priorities
- [x] Loose coupling - easy to swap implementations
- [x] Single registration point in main script
- [x] All dependencies visible in one place
- [x] Easy testing with mock registries
- [x] Cleaner, more maintainable code

---

### Comparison Table

| Feature | Traditional `require()` | Registry |
|---------|------------------------|-----------|
| **Circular Dependencies** | ❌ Common problem | ✅ Eliminated by design |
| **Initialization Order** | ❌ Uncontrolled, implicit | ✅ Fully explicit and controlled |
| **Path Management** | ❌ Hard-coded everywhere | ✅ Centralized registration |
| **Refactoring** | ❌ Update every require() call | ✅ Update one registration |
| **Testing** | ❌ Difficult to mock | ✅ Easy mock registry |
| **Coupling** | ❌ Tight coupling | ✅ Loose coupling |
| **Module Discovery** | ❌ Search for require() calls | ✅ See all in main script |
| **Type Safety** | ⚠️ Manual testing needed | ✅ Full Luau type support |
| **Performance** | ⚠️ Standard | ✅ Native compiled |
| **Dependencies** | ❌ Hidden in code | ✅ Explicit declarations |

---

## Architecture Benefits

### Separation of Concerns

```
Main Script          → Registration & Orchestration
Registry             → Lifecycle Management & Dependency Resolution
Modules              → Business Logic Only
```

### Dependency Graph Clarity

```lua
-- In your main script, you can SEE the entire module structure:
Registry:Register("Core/DataStore", dataStoreModule)
Registry:Register("Services/PlayerService", playerServiceModule)
Registry:Register("Services/ShopService", shopServiceModule)
Registry:Register("Systems/CombatSystem", combatSystemModule)

-- Start in order: guaranteed safe dependency resolution
Registry:SetStartOrder({"Core", "Services", "Systems"})
Registry:RunLifecycle()
```

---

## Best Practices

> [!IMPORTANT]
> Register all modules before calling `InitAll()` or `RunLifecycle()`. Every module must be present before Init runs so dependencies can be resolved.

> [!TIP]
> Use categories and priorities to group related modules and control execution order precisely.

> [!TIP]
> Keep module names unique and descriptive. Use hierarchical names like `"Services/PlayerService"` to mirror your file structure.

> [!TIP]
> Declare dependencies explicitly in the `Dependencies` field. This makes the dependency graph visible and enables cycle detection.

> [!NOTE]
> Get dependencies in `Init`, not `Setup`. The Init stage is when the registry is fully populated and all modules are safe to look up.

> [!TIP]
> Use `Registry:GetMaid(self)` in Init for automatic cleanup. Tracked connections and tasks are flushed when `DestroyAll()` runs.

> [!NOTE]
> Use one registry per context. Keep Server, Client, and Shared registries separate to avoid cross-boundary module access.

> [!TIP]
> Leverage hooks via `Registry:On()` to monitor registration and lifecycle errors during development.

---

## License

This project is open source and available under the [CC0 1.0 Universal License](LICENSE).

Feel free to use, modify, and share this in your projects!

---

## Support

If you find Registry helpful, consider sharing it with other developers or contributing improvements back to the project.

<div align="center">
    <a href="https://www.roblox.com/users/3294832549/profile">
        <img src="https://img.shields.io/badge/Follow%20On%20Roblox-000000?style=for-the-badge&logo=roblox&logoColor=white"></a>
    <a href="https://github.com/sponsors/Kooraseru">
        <img src="https://img.shields.io/badge/Sponsor%20On%20Github-blue?style=for-the-badge&logo=githubsponsors&logoColor=white"></a>
    <a href="https://github.com/Kooraseru-Hub/Registry/issues">
        <img src="https://img.shields.io/badge/Report%20Issues-F36D5D?style=for-the-badge&logo=github&logoColor=white"></a>
    <a href="CONTRIBUTING.md">
        <img src="https://img.shields.io/badge/Contribute-ffb703?style=for-the-badge&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iNDBweCIgdmlld0JveD0iMCAtOTYwIDk2MCA5NjAiIHdpZHRoPSI0MHB4IiBmaWxsPSIjM2U0MjQ1Ij48cGF0aCBkPSJNNjI3LjMzLTU5NS40cS0xOC42Ni0xOS40LTE4LjY2LTQ2LjE3IDAtMjYuNzYgMTguODQtNDQuOTMgMTguODQtMTguMTcgNDUuMjctMTguMTcgMjYuNDQgMCA0NS40OSAxOC4zNSAxOS4wNiAxOC4zNCAxOS4wNiA0NS4xIDAgMjYuNzctMTkuMjMgNDUuOTlRNjk4Ljg2LTU3NiA2NzIuNDMtNTc2cS0yNi40MyAwLTQ1LjEtMTkuNFptLTM4NS4yNyAwcS0xOC43My0xOS40LTE4LjczLTQ2LjE3IDAtMjYuNzYgMTguOTEtNDQuOTMgMTguOS0xOC4xNyA0NS4zMy0xOC4xN3Q0NS4xIDE4LjM1cTE4LjY2IDE4LjM0IDE4LjY2IDQ1LjEgMCAyNi43Ny0xOC44NCA0NS45OVEzMTMuNjUtNTc2IDI4Ny4yMi01NzZxLTI2LjQ0IDAtNDUuMTYtMTkuNFptMTkyLjI3IDExOC4yMlE0MTYtNDk1LjM1IDQxNi01MjIuNDV0MTguNTEtNDYuMzJRNDUzLjAyLTU4OCA0ODAuMTgtNTg4cTI3LjE1IDAgNDUuODIgMTkuNHQxOC42NyA0Ni41cTAgMjcuMS0xOC44NSA0NS4xLTE4Ljg0IDE4LTQ2IDE4LTI3LjE1IDAtNDUuNDktMTguMThabTAtMjM2UTQxNi03MzIuMDIgNDE2LTc1OC44NHEwLTI2LjgzIDE4LjUxLTQ1LjQ5UTQ1My4wMi04MjMgNDgwLjE4LTgyM3EyNy4xNSAwIDQ1LjgyIDE4Ljg0IDE4LjY3IDE4Ljg1IDE4LjY3IDQ1LjY3VDUyNS44Mi03MTNxLTE4Ljg0IDE4LjY3LTQ2IDE4LjY3LTI3LjE1IDAtNDUuNDktMTguODVabTMuNDMgNTcyLjlxLTIyLjI0LTMuMjgtNDIuMDktNy43di0xNTQuMjRxMC0zNy40NiAyMy45NS02NC43OSAyMy45Ni0yNy4zMiA2MC4zNC0yNy4zMiAzNi4zNyAwIDYwLjcxIDI3LjMyUTU2NS0zMzkuNjggNTY1LTMwMi4yMnYxNTQuMjRxLTIwLjUyIDQuNDItNDIuNzMgNy43LTIyLjIyIDMuMjgtNDIuMjUgMy4yOC0yMC4wMiAwLTQyLjI2LTMuMjhaTTMzMS42Ny0xNzJxLTIwLjYzLTcuNS00MS41NC0xOC42MS0yMC45MS0xMS4xMi0zNy40My0yMy41My0zMC41Mi0yMC4wNy00OC4yNy01NC4yOC0xNy43Ni0zNC4yMS0xNy43Ni03NC41OCAwLTI3LjE0LTUuNjctNTIuMjMtNS42Ny0yNS4xLTIwLjMzLTQ2LjEtMTEuMDktMTMuMzYtNDEuNzYtNDEuODRRODguMjQtNTExLjY2IDY1LjMzLTUzNSA1Mi01NDkgNTItNTY1LjgzcTAtMTYuODQgMTIuODMtMzAuMTcgMTIuODQtMTQgMzAtMTQgMTcuMTcgMCAzMC41IDE0bDE2NC44NSAxNTQuNjdxMTkuNDkgMTkuNjYgMzAuNDkgNDYgMTEgMjYuMzMgMTEgNTQuNjZWLTE3MlpNNjI5LTE3MnYtMTY4LjY3cTAtMjguMzMgMTIuNDktNTQuOTggMTIuNS0yNi42NCAzMi43Ny00NS4ybDE2MC41OC0xNTUuNDJxMTIuNDktMTIuNCAzMC42Ni0xMi4wNiAxOC4xNy4zMyAzMC4zMyAxMi4zM1E5MDgtNTgyLjY3IDkwOC01NjUuODMgOTA4LTU0OSA4OTUuMzMtNTM1cS0yMy41NyAyMy4zNC01NC4yNCA1MS4wNC0zMC42NyAyNy43MS00MS4wOSA0Mi42My0xNS4zMyAyMS42Ni0yMC42NyA0Ni4zMy01LjMzIDI0LjY3LTUuMzMgNTEuNzUgMCA0MC41NS0xOC4xNyA3NC43My0xOC4xNiAzNC4xOS00OC41NCA1NC41NC0xNy45NCAxMi41Ni0zOC4wMyAyMy40UTY0OS4xOC0xNzkuNzQgNjI5LTE3MloiLz48L3N2Zz4="></a>
</div>

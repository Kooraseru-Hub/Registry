<div align="center">
  <h1>Registry</h1>
  <p><strong>A lightweight module management system for Roblox Luau</strong></p>
  <p>Organize modules by path, coordinate startup, and clean up resources through a shared lifecycle.</p>
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
- [License](#license)
- [Support](#support)

---

## Why Registry?

Registry gives Roblox experiences one place to register modules, look them up by path, and run their lifecycle. Modules can declare the services they use and resolve them during initialization.

---

## Features

- **Path-based registration** with filesystem-like module organization
- **Dependency management** with warnings for missing dependencies and cycles
- **Full lifecycle control** (Setup → Init → Start → Destroy)
- **Category-based ordering** with priority system for fine-grained control
- **Dependency injection** through the registry pattern
- **Advanced path resolution** with aliases, relative paths, and @prefixes
- **Type-safe** with full Luau strict mode support
- **Hooks system** for monitoring and extending behavior
- **Error tracking** with comprehensive debugging information
- **Maid-based cleanup** for automatic resource management
- **Inspection tools** for monitoring registry state
- **Native compilation** optimized (`--!native`, `--!optimize 2`)

---

## Installation

1. Download `Registry.zip` from [GitHub Releases](https://github.com/Kooraseru-Hub/Registry/releases) or copy `source/Registry` from [main](https://github.com/Kooraseru-Hub/Registry/tree/main).
2. Import it as a ModuleScript tree, with each `init.luau` representing its containing directory.
3. Place Registry in `ReplicatedStorage` for shared use. For a server-only setup, place it in `ServerScriptService` and adjust the require path.

```luau
local Registry = require(game:GetService("ReplicatedStorage").Registry)
```

---

## Quick Start

### Basic Setup

```luau
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require(game:GetService("ReplicatedStorage").Registry)

Registry:Register("Services/DataService", require("./Services/DataService"))
Registry:Register("Services/PlayerService", require("./Services/PlayerService"))
Registry:Register("Systems/CombatSystem", require("./Systems/CombatSystem"))

Registry:SetStartOrder({"Core", "Services", "Systems"})

Registry:InitAll()
Registry:StartAll()
```

### Creating a Module

```luau
-- Services/DataService.lua
--!strict

local DataService = {
    Category = "Services",
    Priority = 10,
    Dependencies = { "Services/PlayerService" },
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

### Core Methods

<details>
<summary><code>Registry:Register(path: string, module: ModuleScript | Module)</code></summary>

Registers a module at the specified absolute path.

**Parameters:**
- `path`: Absolute path (e.g., `"Services/PlayerService"`)
- `module`: ModuleScript instance or pre-loaded module table

**Example:**
```luau
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require(game:GetService("ReplicatedStorage").Registry)

Registry:Register("Services/Database", require("./Services/Database"))
Registry:Register("Controllers/PlayerController", require("./Controllers/PlayerController"))
```
</details>

---

<details>
<summary><code>Registry:Get(target: Resolvable, caller?: Module): Module</code></summary>

Resolves and returns a registered module. The `@game/` prefix refers to a Registry path and does not search the Roblox DataModel.

**Parameters:**
- `target`: A Registry path, a registered ModuleScript instance, or a registered module table.
- `caller`: Required for `@self/`, `./`, and `../` paths.

**Returns:** The resolved module table.

**Example:**
```luau
-- ReplicatedStorage/Shared/Bootstrap.luau
--!strict

local Registry = require(game:GetService("ReplicatedStorage").Registry)

Registry:Register("ReplicatedStorage/Shared/Utils/Logger", { Category = "Utilities" })
Registry:RegisterAlias("shared", "ReplicatedStorage/Shared")

local logger = Registry:Get("@shared/Utils/Logger")
local sameLogger = Registry:Get("@game/ReplicatedStorage/Shared/Utils/Logger")
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
```luau
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require(game:GetService("ReplicatedStorage").Registry)

Registry:Register("ReplicatedStorage/Shared/Utils/Helper", { Category = "Utilities" })
Registry:Register("ServerScriptService/Server/Utils/Logger", { Category = "Utilities" })
Registry:RegisterAlias("shared", "ReplicatedStorage/Shared")
Registry:RegisterAlias("server", "ServerScriptService/Server")

local helper = Registry:Get("@shared/Utils/Helper")
local logger = Registry:Get("@server/Utils/Logger")
```
</details>

<details>
<summary>Alias Demo</summary>

Use aliases when you want a stable import target that does not force every consumer to know the full absolute path.

```luau
-- ServerScriptService/Main.server.lua
--!strict

local Registry = require(game:GetService("ReplicatedStorage").Registry)

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

Executes startup stages in order: Setup → Init → Start. Validates dependencies before running.

```luau
-- ServerScriptService/Main.server.lua
--!strict

Registry:RunLifecycle()
```

---

#### `Registry:SetupAll()`

Runs only the Setup stage on all modules.

```luau
-- ServerScriptService/Main.server.lua
--!strict

Registry:SetupAll()
```

---

#### `Registry:InitAll()`

Runs Setup and Init stages. Validates dependencies and reports cycles.

```luau
-- ServerScriptService/Main.server.lua
--!strict

Registry:InitAll()
```

---

#### `Registry:StartAll()`

Runs the Start stage on all modules in category order.

```luau
-- ServerScriptService/Main.server.lua
--!strict

Registry:StartAll()
```

---

#### `Registry:DestroyAll()`

Runs Destroy stage in reverse registration order, then flushes per-module Maids.

```luau
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
```luau
-- ServerScriptService/Main.server.lua
--!strict

Registry:SetStartOrder({"Core", "Services", "Systems", "UI"})
```

---

### Utilities

#### `Registry:IsRegistered(path: string, caller?: Module): boolean`

Returns true if the given path resolves to a registered module.

```luau
if Registry:IsRegistered("Services/Database") then
    local db = Registry:Get("Services/Database")
end
```

---

#### `Registry:GetDescendants(path: string, caller?: Module): { Module }`

Returns all modules whose paths are descendants of the given path.

```luau
local controllers = Registry:GetDescendants("Controllers")
```

---

#### `Registry:GetByCategory(category: string): { Module }`

Returns all modules with the given category.

```luau
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

```luau
Registry:On("AfterRegister", function(path, module)
    print("Registered:", path)
end)

Registry:On("OnError", function(module, path, stage, message)
    warn("Error in", path, "during", stage, message)
end)
```

---

#### `Registry:GetErrors(): { [Module]: { ErrorRecord } }`

Returns error state for all modules.

```luau
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

```luau
print(Registry:ListModules())
-- Output:
-- [Registry] 3 module(s):
--   [Services/Database] (Services, p=10)
--   [Services/PlayerService] (Services, p=20) !ERR
--   [Systems/Combat] (Systems, p=5)
```

---

#### `Registry:Inspect(): InspectorSnapshot`

Returns a diagnostic snapshot of registry state.

```luau
local snapshot = Registry:Inspect()
print("Modules:", snapshot.moduleCount)
print("Categories:", snapshot.categoryCount)
print("Errors:", snapshot.errorCount)
```

---

#### `Registry:GetMaid(module: Module): Maid`

Returns the per-module Maid for automatic resource cleanup.

```luau
local maid = Registry:GetMaid(MyModule)
maid:Track(someConnection)
```

---

## Examples

### Example 1: Server Setup with Ordered Initialization

```luau
-- ServerScriptService/Main.server.lua
local Registry = require(game:GetService("ReplicatedStorage").Registry)

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

```

---

### Example 2: Module with Dependencies

This example uses the services registered in Example 1.

```luau
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

```luau
-- StarterPlayer/StarterPlayerScripts/ClientMain.client.lua
local Registry = require(game:GetService("ReplicatedStorage").Registry)

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

Register this module and its player-service dependency before starting the lifecycle.

```luau
-- Example showing all lifecycle methods
local MyModule = {
    Category = "Systems",
    Priority = 50,
    Dependencies = { "Services/PlayerService" },
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

### Direct requires

```luau
-- Services/ShopService.lua
local InventoryService = require("../InventoryService")  -- Path dependency
local DataStore = require("../Core/DataStore")     -- Path dependency
local NetworkManager = require("@self/NetworkManager") -- Hard-coded path

local ShopService = {}

function ShopService:PurchaseItem(player, itemId)
    -- A require back to ShopService would create a load-time cycle.
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

### Registry lookup

```luau
-- Services/ShopService.lua
local ShopService = {
    Dependencies = {
        "Services/InventoryService",
        "Core/DataStore",
        "Core/NetworkManager",
    }
}

function ShopService:Init(registry, name)
    -- Resolve the registered paths declared above.
    self.InventoryService = registry:Get("Services/InventoryService")
    self.DataStore = registry:Get("Core/DataStore")
    self.NetworkManager = registry:Get("Core/NetworkManager")
end

function ShopService:PurchaseItem(player, itemId)
    -- Use the dependency saved during Init.
    self.InventoryService:AddItem(player, itemId)
end

return ShopService
```

**Advantages:**

- Registry paths stay stable when ModuleScripts move.
- Modules can resolve declared dependencies during Init after registration.
- Controlled initialization order with categories and priorities
- Loose coupling - easy to swap implementations
- Single registration point in main script
- All dependencies visible in one place
- Easy testing with mock registries
- Cleaner, more maintainable code

---

### Comparison Table

| Feature | Traditional `require()` | Registry |
|---------|------------------------|-----------|
| Dependency validation | Lua require cycles surface during loading | Missing registrations and declared cycles are reported before startup |
| **Initialization Order** | Determined by load and calling code | Category order and priority control lifecycle stages |
| **Path Management** | ❌ Hard-coded everywhere | ✅ Centralized registration |
| **Refactoring** | ❌ Update every require() call | ✅ Update one registration |
| **Testing** | ❌ Difficult to mock | ✅ Easy mock registry |
| **Coupling** | ❌ Tight coupling | ✅ Loose coupling |
| **Module Discovery** | ❌ Search for require() calls | ✅ See all in main script |
| **Type Safety** | Luau can infer types from direct requires | Registry exposes types for its module and lifecycle contracts |


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

```luau
-- In your main script, you can SEE the entire module structure:
Registry:Register("Core/DataStore", dataStoreModule)
Registry:Register("Services/PlayerService", playerServiceModule)
Registry:Register("Services/ShopService", shopServiceModule)
Registry:Register("Systems/CombatSystem", combatSystemModule)

-- Start in order: validate dependencies and use the configured category order
Registry:SetStartOrder({"Core", "Services", "Systems"})
Registry:RunLifecycle()
```

---

## Best Practices

> [!IMPORTANT]
> Register all modules before calling `InitAll()` or `RunLifecycle()`. A lookup for a module that was never registered raises an error.

> [!TIP]
> Use categories and priorities to group related modules and control execution order precisely.

> [!TIP]
> Keep module names unique and descriptive. Use hierarchical names like `"Services/PlayerService"` to mirror your file structure.

> [!WARNING]
> Declare dependencies in `Dependencies`. Registry warns about missing registrations and cycles, then continues the lifecycle. Use category order and priority to control startup order.

> [!NOTE]
> Get dependencies in `Init`, not `Setup`. After registration, Init receives the registry and the module’s registered path. Use category order and priority if a dependency must initialize first.

> [!TIP]
> Use `Registry:GetMaid(self)` in Init for automatic cleanup. `DestroyAll()` cleans up modules that successfully ran `Init`, in reverse initialization order.

> [!NOTE]
> Server and client have separate Registry state. Putting the ModuleScript in ReplicatedStorage lets both sides require it. Register their modules independently.

> [!TIP]
> Leverage hooks via `Registry:On()` to monitor registration and lifecycle errors during development.

---

## License

This project is open source and available under the [CC0 1.0 Universal License](LICENSE).

Feel free to use, modify, and share this in your projects!

---

## Support

<div align="center">
  <a href="https://github.com/Kooraseru-Hub/Registry/issues/new/choose">Report an issue</a> ·
  <a href="https://github.com/Kooraseru-Hub/Registry/tree/source">Contribute</a> ·
  <a href="https://www.roblox.com/users/3294832549/profile">Roblox profile</a>
</div>

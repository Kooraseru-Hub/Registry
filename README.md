<h1 align="center">Registry</h1>

<p align="center">
  <strong>A lightweight, type-safe module management system for Roblox</strong><br>
  Streamline module initialization, eliminate circular dependencies, and optimize your codebase with native compilation support.
</p>

<div align="center">
    <a href="Source Code">
        <img src="https://img.shields.io/badge/Source%20Code-00A2FF?style=for-the-badge&logo=github&logoColor=white">
    </a>
    <a href="https://create.roblox.com/store/asset/83203149398671/Registry">
        <img src="https://img.shields.io/badge/Download-000000?style=for-the-badge&logo=luau&logoColor=white">
    </a>
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

---

## Why Registry?

Traditional module management in Roblox involves scattered `require()` calls throughout your codebase, leading to:

- **Circular dependency nightmares**
- **Tight coupling** between modules
- **No control over initialization order**
- **Repeated require statements** causing clutter
- **Difficult refactoring** when restructuring code

**Registry** solves these problems by centralizing module management and providing a clean lifecycle system.

---

## Features

- ✅ **Type-safe** with full Luau strict mode support
- ✅ **Native compilation** optimized (`--!native`, `--!optimize 2`)
- ✅ **Lifecycle management** (Setup → Init → Start → Destroy)
- ✅ **Ordered initialization** with category-based starting
- ✅ **Dependency injection** through the registry pattern
- ✅ **Context-aware** (Server/Client/Shared)
- ✅ **Zero circular dependencies** - modules get references through registry
- ✅ **Instance-based registration** - register and retrieve modules by name or Instance reference
- ✅ **Clean architecture** with separation of concerns

---

## Installation

1. Download `Registry.lua` from this repository
2. Place it in `ReplicatedStorage` (for shared access) or `ServerScriptService` (server-only)
3. Require it once in your main script

```lua
local Registry = require(game.ReplicatedStorage.Registry)
```

---

## Quick Start

### Basic Setup

```lua
-- ServerScriptService/Main.server.lua
local Registry = require(game.ReplicatedStorage.Registry)
local registry = Registry.new("Server")

-- Register your modules
registry:Register("DataService", script.Parent.Services.DataService)
registry:Register("PlayerService", script.Parent.Services.PlayerService)
registry:Register("CombatSystem", script.Parent.Systems.CombatSystem)

-- Initialize and start all modules
registry:InitAll()   -- Calls Init() on all modules
registry:StartAll()  -- Calls Start() on all modules
```

### Creating a Module

```lua
-- Services/DataService.lua
local DataService = {}

-- Optional: Called during InitAll() - receives registry and module name
function DataService:Init(registry, name)
    print("DataService initializing as:", name)
    
    -- Get other modules from registry (no circular dependencies!)
    self.PlayerService = registry:Get("PlayerService")
end

-- Optional: Called during StartAll() - modules are ready
function DataService:Start()
    print("DataService started!")
    -- Start listening to events, connect to databases, etc.
end

-- Your custom methods
function DataService:SavePlayer(player)
    -- Implementation
end

return DataService
```

---

## API Reference

### Constructor

#### `Registry.new(context: RegistryContext): Registry`

Creates a new registry instance.

**Parameters:**

- `context`: `"Server"` | `"Client"` | `"Shared"`

**Returns:** Registry instance

```lua
local registry = Registry.new("Server")
```

---

### Methods

#### `registry:Register(name: string | Instance, module: ModuleScript | Module, category?: string)`

Registers a module with a unique name and optional category.

**Parameters:**

- `name`: Unique identifier for the module (string) or Instance (name will be extracted from `Instance.Name`)
- `module`: ModuleScript instance or module table
- `category`: Optional category for ordered starting

```lua
-- Register by name string
registry:Register("DataService", script.Services.DataService, "Core")

-- Register by Instance (uses Instance.Name automatically)
local dataService = script.Services.DataService
registry:Register(dataService, dataService, "Core")
```

---

#### `registry:Get(nameOrInstance: string | Instance): Module`

Retrieves a registered module by name or Instance reference.

**Parameters:**

- `nameOrInstance`: Module identifier (string) or Instance reference

**Returns:** Module table

```lua
-- Get by name string
local dataService = registry:Get("DataService")
dataService:SavePlayer(player)

-- Get by Instance reference
local dataService = registry:Get(script.Services.DataService)
dataService:SavePlayer(player)
```

---

#### `registry:InitAll()`

Calls `Init(registry, name)` on all registered modules that have an Init method.

```lua
registry:InitAll()
```

---

#### `registry:StartAll()`

Calls `Start()` on all registered modules in arbitrary order.

```lua
registry:StartAll()
```

---

#### `registry:StartOrdered(startOrder: {string})`

Starts modules by category in a specific order.

**Parameters:**

- `startOrder`: Array of category names defining execution order

```lua
registry:StartOrdered({"Core", "Services", "Systems", "UI"})
```

---

## Examples

### Example 1: Server Setup with Ordered Initialization

```lua
-- ServerScriptService/Main.server.lua
local Registry = require(game.ReplicatedStorage.Registry)
local registry = Registry.new("Server")

-- Core systems that others depend on
registry:Register("DataStore", script.Parent.Core.DataStore, "Core")
registry:Register("NetworkManager", script.Parent.Core.NetworkManager, "Core")

-- Services layer (can use Instance-based registration)
local playerService = script.Parent.Services.PlayerService
registry:Register(playerService, playerService, "Services")  -- Uses Instance.Name
registry:Register("InventoryService", script.Parent.Services.InventoryService, "Services")
registry:Register("ShopService", script.Parent.Services.ShopService, "Services")

-- Game systems
registry:Register("CombatSystem", script.Parent.Systems.CombatSystem, "Systems")
registry:Register("QuestSystem", script.Parent.Systems.QuestSystem, "Systems")

-- Initialize all modules (they can now cross-reference each other)
registry:InitAll()

-- Start in order: Core → Services → Systems
registry:StartOrdered({"Core", "Services", "Systems"})

print("Server initialized successfully!")
```

---

### Example 2: Module with Dependencies

```lua
-- Services/ShopService.lua
local ShopService = {}

function ShopService:Init(registry, name)
    -- Get dependencies from registry (no require() needed!)
    self.InventoryService = registry:Get("InventoryService")
    self.DataStore = registry:Get("DataStore")
    self.NetworkManager = registry:Get("NetworkManager")
    
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
local Registry = require(game.ReplicatedStorage.Registry)
local registry = Registry.new("Client")

-- Register UI controllers
registry:Register("UIController", script.Parent.UI.UIController, "UI")
registry:Register("HUDController", script.Parent.UI.HUDController, "UI")
registry:Register("InventoryUI", script.Parent.UI.InventoryUI, "UI")

-- Register client systems
registry:Register("InputHandler", script.Parent.Systems.InputHandler, "Systems")
registry:Register("CameraController", script.Parent.Systems.CameraController, "Systems")
registry:Register("SoundManager", script.Parent.Systems.SoundManager, "Systems")

-- Initialize and start
registry:InitAll()
registry:StartOrdered({"Systems", "UI"})
```

---

### Example 4: Module Lifecycle

```lua
-- Example showing all lifecycle methods
local MyModule = {}

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
    self.playerService = registry:Get("PlayerService")
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
local InventoryService = require(script.Parent.InventoryService)  -- Path dependency
local DataStore = require(script.Parent.Parent.Core.DataStore)     -- Path dependency
local NetworkManager = require(game.ReplicatedStorage.NetworkManager) -- Hard-coded path

local ShopService = {}

function ShopService:PurchaseItem(player, itemId)
    -- What if InventoryService also requires ShopService? CIRCULAR DEPENDENCY! ⚠️
    InventoryService:AddItem(player, itemId)
end

return ShopService
```

**Problems:**

- 🔴 Hard-coded paths break when restructuring
- 🔴 Circular dependencies cause runtime errors
- 🔴 No control over initialization order
- 🔴 Tight coupling makes testing difficult
- 🔴 Repeated `require()` statements everywhere

---

### ✅ Registry Approach

```lua
-- Services/ShopService.lua
local ShopService = {}

function ShopService:Init(registry, name)
    -- Clean dependency injection - no paths, no circular dependencies!
    self.InventoryService = registry:Get("InventoryService")
    self.DataStore = registry:Get("DataStore")
    self.NetworkManager = registry:Get("NetworkManager")
end

function ShopService:PurchaseItem(player, itemId)
    -- All dependencies are ready and safe to use
    self.InventoryService:AddItem(player, itemId)
end

return ShopService
```

**Advantages:**

- ✅ No hard-coded paths - reference by name
- ✅ Zero circular dependencies - Init happens after all modules are registered
- ✅ Controlled initialization order with categories
- ✅ Loose coupling - easy to swap implementations
- ✅ Single registration point in main script
- ✅ Easy testing with mock registries
- ✅ Cleaner, more maintainable code

---

### Comparison Table

| Feature | Traditional `require()` | Registry |
|---------|------------------------|-----------|
| **Circular Dependencies** | ❌ Common problem | ✅ Eliminated |
| **Initialization Order** | ❌ Uncontrolled | ✅ Fully controlled |
| **Path Management** | ❌ Hard-coded everywhere | ✅ Centralized registration |
| **Refactoring** | ❌ Update every require | ✅ Update one registration |
| **Testing** | ❌ Difficult to mock | ✅ Easy mock registry |
| **Coupling** | ❌ Tight | ✅ Loose |
| **Module Discovery** | ❌ Search for require() | ✅ See all in main script |
| **Type Safety** | ⚠️ Manual | ✅ Full Luau types |
| **Performance** | ⚠️ Standard | ✅ Native compiled |

---

## Architecture Benefits

### Separation of Concerns

```
Main Script          → Registration & Orchestration
Registry             → Lifecycle Management
Modules              → Business Logic Only
```

### Dependency Graph Clarity

```lua
-- In your main script, you can SEE the entire module structure:
registry:Register("Core", coreModule, "Core")
registry:Register("ServiceA", serviceA, "Services")  -- Depends on Core
registry:Register("ServiceB", serviceB, "Services")  -- Depends on Core
registry:Register("SystemX", systemX, "Systems")     -- Depends on Services

-- Start in order:
registry:StartOrdered({"Core", "Services", "Systems"})
```

---

## Best Practices

1. **Register all modules before InitAll()** - Ensures all modules can find their dependencies
2. **Use categories for ordered starting** - Group related modules together
3. **Keep module names unique** - Use descriptive names like "PlayerDataService"
4. **Get dependencies in Init, use them in Start** - Clean separation of setup and execution
5. **One registry per context** - Separate registries for Server, Client, and Shared
6. **Store registry reference** - Keep the registry in a global or module scope if needed
7. **Instance-based registration** - You can register modules using Instance references instead of strings for more dynamic registration patterns

---

## License

This project is open source and available for use in your Roblox projects.

Feel free to share, modify, do whatever you want to this!

---

## Support Me

If you find Registry helpful for your Roblox projects, consider supporting its development:

[![Roblox](https://img.shields.io/badge/Follow%20On%20Roblox-000000?style=for-the-badge&logo=roblox&logoColor=white)](https://www.roblox.com/users/3294832549/profile)
[![Github](https://img.shields.io/badge/Sponsor%20On%20Github-blue?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Kooraseru)
[![Issues](https://img.shields.io/badge/Report%20Bugs-F36D5D?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Kooraseru-Hub/Registry/issues)

Your support helps maintain and improve this project, and future ones to come!

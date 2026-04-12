-- src/Shared/Registry/Core/Types.luau
--!strict

export type Module = {
	Setup: ((self: Module) -> ())?,
	Init: ((self: Module, registry: Registry, name: string) -> ())?,
	Start: ((self: Module) -> ())?,
	Destroy: ((self: Module, registry: Registry) -> ())?,
	Priority: number?,
	Category: string?,
	Dependencies: { string }?,
	Version: string?,
	Description: string?,
}

export type Resolvable = string | ModuleScript | Script | LocalScript | Module

export type HookEvent =
	"BeforeRegister"
	| "AfterRegister"
	| "BeforeStage"
	| "AfterStage"
	| "OnError"

export type HookCallback = (...any) -> ()

export type HookConnection = {
	Disconnect: (self: HookConnection) -> (),
}

export type Hooks = {
	On: (self: Hooks, event: HookEvent, callback: HookCallback) -> HookConnection,
	Fire: (self: Hooks, event: HookEvent, ...any) -> (),
}

export type LifecycleEntry = {
	stage: string,
	method: string,
	passRegistry: boolean?,
	passPath: boolean?,
}

export type Trackable =
	RBXScriptConnection
	| thread
	| (() -> ())
	| { Destroy: (any) -> () }
	| { Disconnect: (any) -> () }

export type Maid = {
	Track: (self: Maid, item: Trackable) -> number,
	Untrack: (self: Maid, token: number) -> (),
	CleanUp: (self: Maid) -> (),
}

export type ErrorRecord = {
	stage: string,
	error: string,
}

export type RegistryState = {
	ModulesByPath: { [string]: Module },
	ModulePaths: { [Module]: string },
	RegistrationOrder: { [Module]: number },
	InstanceToPath: { [Instance]: string },
	Aliases: { [string]: string },
	Hooks: Hooks,
	Categories: { [string]: { Module } },
	CategoryOrder: { string }?,
	ModuleMaids: { [Module]: Maid },
	InitOrder: { Module },
	ErrorState: { [Module]: { ErrorRecord } },
	DepsValidated: boolean,
	NextRegistrationIndex: number,
}

export type Registry = {
	ModulesByPath: { [string]: Module },
	ModulePaths: { [Module]: string },
	RegistrationOrder: { [Module]: number },
	InstanceToPath: { [Instance]: string },
	Aliases: { [string]: string },
	Hooks: Hooks,
	Categories: { [string]: { Module } },
	CategoryOrder: { string }?,
	ModuleMaids: { [Module]: Maid },
	InitOrder: { Module },
	ErrorState: { [Module]: { ErrorRecord } },
	DepsValidated: boolean,
	NextRegistrationIndex: number,

	Register: (self: Registry, path: string, module: ModuleScript | Module) -> (),
	RegisterAlias: (self: Registry, alias: string, path: string) -> (),
	Get: (self: Registry, target: Resolvable, caller: Module?) -> Module,
	GetDescendants: (self: Registry, path: string, caller: Module?) -> { Module },
	GetByCategory: (self: Registry, category: string) -> { Module },
	SetStartOrder: (self: Registry, order: { string }) -> (),
	On: (self: Registry, event: HookEvent, callback: HookCallback) -> HookConnection,
	IsRegistered: (self: Registry, path: string, caller: Module?) -> boolean,
	RunLifecycle: (self: Registry) -> (),
	SetupAll: (self: Registry) -> (),
	InitAll: (self: Registry) -> (),
	StartAll: (self: Registry) -> (),
	DestroyAll: (self: Registry) -> (),
	Reset: (self: Registry) -> (),
	GetMaid: (self: Registry, module: Module) -> Maid,
	GetErrors: (self: Registry) -> { [Module]: { ErrorRecord } },
	Inspect: (self: Registry) -> InspectorSnapshot,
	ListModules: (self: Registry) -> string,
}

export type InspectorEntry = {
	path: string,
	category: string?,
	priority: number,
	version: string?,
	description: string?,
	hasErrors: boolean,
}

export type InspectorSnapshot = {
	moduleCount: number,
	categoryCount: number,
	errorCount: number,
	categories: { [string]: number },
}

return {}

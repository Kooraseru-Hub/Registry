-- src/Shared/Registry/Stages/init.luau
--!strict

local Types = require("./Core/Types")

export type LifecycleEntry = Types.LifecycleEntry

local Stages = {}

Stages.Entries = {
	{
		stage = "Setup",
		method = "Setup",
	},
	{
		stage = "Init",
		method = "Init",
		passRegistry = true,
		passPath = true,
	},
	{
		stage = "Start",
		method = "Start",
	},
} :: { LifecycleEntry }

Stages.Drivers = {
	Setup = require("@self/Setup"),
	Init = require("@self/Init"),
	Start = require("@self/Start"),
	Destroy = require("@self/Destroy"),
}

return Stages

--!strict

const Registry = require("@game/ReplicatedStorage/Registry")
const fixtures = script.Parent.Fixtures

return Registry.Register({
	["Data/Scalar"] = fixtures.Scalar,
	["Data/Alternate"] = fixtures.Alternate,
	["Data/Broken"] = fixtures.Broken,
})

local tests = game.ReplicatedStorage.tests.registry
if require(tests.Lookup.Consumer).Run() then
	print("REGISTRY_LOOKUP_OK")
end

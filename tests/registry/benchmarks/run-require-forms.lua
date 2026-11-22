local loadModule: (ModuleScript) -> { Measure: (string, number) -> (number, boolean) } = require
local template = game.ReplicatedStorage.benchmarks.registry.RequireForms
local forms = {"literalPath", "dynamicPath", "directInstance", "boundInstance", "indirectInstance", "registry"}
for _, calls in {1, 100000} do
	for trial = 1, 6 do
		for offset = 0, #forms - 1 do
			local name = forms[(trial + offset - 1) % #forms + 1]
			local seconds = 0
			local batches = if calls == 1 then 64 else 1
			for _ = 1, batches do
				local copy = template:Clone()
				copy.Parent = template.Parent
				local elapsed, valid = loadModule(copy).Measure(name, calls)
				copy:Destroy()
				if not valid then error("Checksum mismatch: " .. name) end
				seconds += elapsed
			end
			print(string.format("REQUIRE_FORMS %d %d %s %.9f", calls * batches, trial, name, seconds))
		end
	end
end
print("REQUIRE_FORMS_OK")

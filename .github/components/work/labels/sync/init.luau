-- .github/components/work/labels/sync/init.luau
--!strict

const LabelCatalog = require("@self/labelCatalog")
const LabelSync = require("@self/labelSync")
const Publication = require("@ci/github/publication")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component used to synchronize repository labels.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Synchronize GitHub labels from the validated repository catalog.
function Component.Run(self: Component, _: { event: string }): string?
	local labels = LabelCatalog.Read()
	local repository = Publication.Begin("LABELS")
	if not repository then
		return "skipped"
	end
	if not LabelSync.Sync(repository, labels, Publication.Request) then
		print("GitHub labels already match the catalog; reconciliation completed successfully")
	end
	return nil
end

return Component

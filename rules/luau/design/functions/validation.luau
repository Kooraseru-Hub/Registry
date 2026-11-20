-- rules/luau/design/functions/validation.luau
--!strict

const Diagnostic = require("@ruleLinter/diagnostic")
const Parser = require("@std/syntax/parser")
const Query = require("@std/syntax/query")
const Rule = require("@ruleLinter/rule")
const Utils = require("@std/syntax/utils")

return Rule.new(function(context: Rule.Context): { Diagnostic.Finding }
	local parsed, block = pcall(Parser.parseBlock, context.source)
	if not parsed then
		return {}
	end
	local last = block.statements[#block.statements]
	if not last or last.tag ~= "return" or #last.expressions == 0 then
		return {}
	end
	local findings: { Diagnostic.Finding } = {}
	-- Inspect named function declarations for unintended global bindings.
	for _, statement in Query.findAllFromRoot(block, Utils.isStatFunction).nodes do
		local name = statement.name
		if name.tag ~= "global" then
			continue
		end
		local span = name.location
		findings[#findings + 1] = {
			line = span.beginLine, column = span.beginColumn,
			endLine = span.endLine, endColumn = span.endColumn,
			severity = "warning", message = "A bare function declaration in a returning module writes a global. Declare a local helper or a method on the module surface.",
		}
	end
	return findings
end)

-- rules/luau/design/function-modules/validation.luau
--!strict

const Diagnostic = require("@ruleLinter/diagnostic")
const Parser = require("@std/syntax/parser")
const Query = require("@std/syntax/query")
const Rule = require("@ruleLinter/rule")
const Syntax = require("@std/syntax")
const Utils = require("@std/syntax/utils")

type SourceRange = {
	read beginLine: number,
	read beginColumn: number,
	read endLine: number,
	read endColumn: number,
}

--- Find a module wrapper exposed through a named callable member.
local function namedWrapper(block: Syntax.CstStatBlock, stem: string): SourceRange?
	local binding, method, returned = block.statements[1], block.statements[2], block.statements[3]
	if binding.tag ~= "local" and binding.tag ~= "const" then
		return nil
	end
	if #binding.variables ~= 1 or #binding.values ~= 1 or method.tag ~= "function" or returned.tag ~= "return" then
		return nil
	end
	local identity = binding.variables[1]
	local initial = binding.values[1]
	if identity.name.text ~= stem or initial.tag ~= "table" or #initial.entries ~= 0 or #returned.expressions ~= 1 then
		return nil
	end
	local member = method.name
	local result = returned.expressions[1]
	if member.tag ~= "indexname" or member.accessor.text ~= "." or member.index.text ~= stem or result.tag ~= "local" then
		return nil
	end
	local receiver = member.expression
	if receiver.tag ~= "local" or receiver["local"] ~= identity or result["local"] ~= identity then
		return nil
	end

	-- Check whether the wrapper body references its own exported binding.
	for _, reference in Query.findAllFromRoot(method.func, Utils.isExprLocal).nodes do
		if reference["local"] == identity then
			return nil
		end
	end

	-- Return the wrapper location once the declaration has been identified.
	return {
		beginLine = binding.location.beginLine, beginColumn = binding.location.beginColumn,
		endLine = returned.location.endLine, endColumn = returned.location.endColumn,
	}
end

--- Determine whether an explicit string key matches the module stem.
local function matchesQuotedName(key: Syntax.CstExpr, stem: string): boolean
	return key.tag == "string" and (key.quoteStyle == "single" or key.quoteStyle == "double")
		and key.value.text == stem
end

--- Find a module wrapper returned inline as a table member.
local function inlineWrapper(statement: Syntax.CstStat, stem: string): Syntax.Span?
	if statement.tag ~= "return" or #statement.expressions ~= 1 then
		return nil
	end
	local result = statement.expressions[1]
	if result.tag ~= "table" or #result.entries ~= 1 then
		return nil
	end
	local member = result.entries[1]
	local matchesName = (member.kind == "record" and member.key.text == stem)
		or (member.kind == "general" and matchesQuotedName(member.key, stem))
	if matchesName and member.value.tag == "function" then
		return result.location
	end
	return nil
end

--- Find a module wrapper created by binding a function before export.
local function boundWrapper(block: Syntax.CstStatBlock, stem: string): SourceRange?
	local binding, returned = block.statements[1], block.statements[2]
	if (binding.tag ~= "local" and binding.tag ~= "const") or #binding.variables ~= 1
		or #binding.values ~= 1 or binding.values[1].tag ~= "function"
		or returned.tag ~= "return" or #returned.expressions ~= 1 then
		return nil
	end
	local result = returned.expressions[1]
	if result.tag ~= "table" or #result.entries ~= 1 then
		return nil
	end
	local member = result.entries[1]
	local matchesName = (member.kind == "record" and member.key.text == stem)
		or (member.kind == "general" and matchesQuotedName(member.key, stem))
	if not matchesName or member.value.tag ~= "local"
		or member.value["local"] ~= binding.variables[1] then
		return nil
	end
	return {
		beginLine = binding.location.beginLine, beginColumn = binding.location.beginColumn,
		endLine = returned.location.endLine, endColumn = returned.location.endColumn,
	}
end

return Rule.new(function(context: Rule.Context): { Diagnostic.Finding }
	local stem = context.path:match("([^/\\]+)%.luau$")
	if not stem or stem == "init" or stem == "index" then
		return {}
	end
	local parsed, block = pcall(Parser.parseBlock, context.source)
	if not parsed then
		return {}
	end
	local span = if #block.statements == 1 then inlineWrapper(block.statements[1], stem)
		elseif #block.statements == 2 then boundWrapper(block, stem)
		elseif #block.statements == 3 then namedWrapper(block, stem)
		else nil
	if not span then
		return {}
	end
	return {{
		line = span.beginLine, column = span.beginColumn,
		endLine = span.endLine, endColumn = span.endColumn,
		severity = "warning", message = "This table repeats the module name around one function. Consider returning the function directly after checking its callers.",
	}}
end)

-- rules/luau/syntax/control-flow/validation.luau
--!strict

const Diagnostic = require("@ruleLinter/diagnostic")
const Rule = require("@ruleLinter/rule")
const Parser = require("@std/syntax/parser")
const Query = require("@std/syntax/query")
const Syntax = require("@std/syntax")
const Utils = require("@std/syntax/utils")

--- Recognize expressions that can be used as boolean conditions.
local function isBooleanExpression(expression: Syntax.CstExpr): boolean
	if expression.tag == "group" then
		return isBooleanExpression(expression.expression)
	elseif expression.tag == "boolean" then
		return true
	elseif expression.tag == "unary" then
		return expression.operator.text == "not"
	elseif expression.tag ~= "binary" then
		return false
	end
	local operator = expression.operator.text
	if operator == "and" or operator == "or" then
		return isBooleanExpression(expression.lhsOperand) and isBooleanExpression(expression.rhsOperand)
	end
	return operator == "==" or operator == "~=" or operator == "<" or operator == "<="
		or operator == ">" or operator == ">="
end

--- Determine whether a statement group can be moved out of its enclosing branch.
local function canUnnest(statements: { Syntax.CstStat }): boolean
	for _, statement in statements do
		if statement.tag == "assign" or statement.tag == "compoundassign" then
			continue
		end
		if statement.tag ~= "expression" or statement.expression.tag ~= "call" then
			return false
		end
	end
	return #statements > 0
end

--- Recognize a direct call that exits by throwing an error.
local function isErrorCall(statement: Syntax.CstStat): boolean
	if statement.tag ~= "expression" or statement.expression.tag ~= "call" then
		return false
	end
	local callee = statement.expression.func
	return callee.tag == "global" and callee.name.text == "error"
end

--- Convert a source line and byte column into a source offset.
local function offsetAt(source: string, line: number, column: number): number
	local offset = 1
	for _ = 1, line - 1 do
		local newline = source:find("\n", offset, true)
		if not newline then
			return #source + 1
		end
		offset = newline + 1
	end
	return offset + column - 1
end

return Rule.new(function(context: Rule.Context): { Diagnostic.Finding }
	local parsed, block = pcall(Parser.parseBlock, context.source)
	if not parsed then
		return {}
	end
	local findings: { Diagnostic.Finding } = {}

	-- Look for conditional expressions that can use simpler control flow.
	for _, node in Query.findAllFromRoot(block, Utils.isExprIfElse).nodes do
		local yes, no = node.thenExpr, node.elseExpr
		if node.conditionLocal or #node.elseifs > 0 or yes.tag ~= "boolean" or no.tag ~= "boolean" or yes.value == no.value then
			continue
		end
		if yes.value and not isBooleanExpression(node.condition) then
			continue
		end
		local span = node.location
		local fix: Diagnostic.SuggestedEdit? = nil
		local wholeStart = offsetAt(context.source, span.beginLine, span.beginColumn)
		local wholeEnd = offsetAt(context.source, span.endLine, span.endColumn)
		local conditionStart = offsetAt(context.source, node.condition.location.beginLine, node.condition.location.beginColumn)
		local conditionEnd = offsetAt(context.source, node.condition.location.endLine, node.condition.location.endColumn)
		local wholeText = context.source:sub(wholeStart, wholeEnd - 1)

		if not wholeText:find("%-%-") then
			local replacement = context.source:sub(conditionStart, conditionEnd - 1)
			if not yes.value then
				replacement = "not (" .. replacement .. ")"
			end
			fix = {
				title = if yes.value then "Use the condition directly" else "Negate the condition",
				range = { line = span.beginLine, column = span.beginColumn, endLine = span.endLine, endColumn = span.endColumn },
				text = replacement,
			}
		end

		findings[#findings + 1] = {
			fix = fix,
			line = span.beginLine, column = span.beginColumn,
			endLine = span.endLine, endColumn = span.endColumn,
			severity = "warning",
			message = if yes.value then "Use the boolean expression directly." else "Use not to express the negated condition.",
		}
	end

	-- Inspect call expressions for control-flow patterns handled by this rule.
	for _, call in Query.findAllFromRoot(block, Utils.isExprCall).nodes do
		local callee = call.func
		local protected = call.arguments[1]
		if callee.tag == "global" and callee.name.text == "pcall" and protected
			and protected.tag == "global" and protected.name.text == "assert" then
			local span = call.location
			findings[#findings + 1] = {
				line = span.beginLine, column = span.beginColumn,
				endLine = span.endLine, endColumn = span.endColumn,
				severity = "warning", message = "Use an explicit guard or error result when recovering from a built-in assertion.",
			}
		end
	end

	-- Check statement conditionals after processing expression-level candidates.
	for _, node in Query.findAllFromRoot(block, Utils.isStatIf).nodes do
		local fallback = node.elseBlock
		if node.conditionLocal or #node.elseifs ~= 0 or not fallback then
			continue
		end
		local success = node.thenBlock.statements
		local failure = fallback.statements
		if #failure ~= 1 or not canUnnest(success) then
			continue
		end
		local exit = failure[1]
		local returnsNoResult = exit.tag == "return" and (#exit.expressions == 0
			or exit.expressions[1].tag == "nil")
		if exit.tag ~= "continue" and exit.tag ~= "break" and not returnsNoResult and not isErrorCall(exit) then
			continue
		end
		local span = node.location
		findings[#findings + 1] = {
			line = span.beginLine, column = span.beginColumn,
			endLine = span.endLine, endColumn = span.endColumn,
			severity = "warning", message = "Handle the early exit first, then run the successful operation.",
		}
	end
	return findings
end)

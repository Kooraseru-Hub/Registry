-- dependencies/packages/checks/ruleLinter/rule.luau
--!strict

const Diagnostic = require("@ruleLinter/diagnostic")

export type Context = {
	path: string,
	source: string,
}

export type Validation = (context: Context) -> { Diagnostic.Finding }

local Rule = {}
Rule.__index = Rule

type RuleFields = { validate: Validation }
export type Rule = setmetatable<RuleFields, typeof(Rule)>

--- Wrap a validator in the rule interface used by the lint runner.
function Rule.new(validate: Validation): Rule
	local fields: RuleFields = { validate = validate }
	return setmetatable(fields, Rule)
end

--- Evaluate this rule against a source context and return its findings.
function Rule.Check(self: Rule, context: Context): { Diagnostic.Finding }
	return self.validate(context)
end

return Rule

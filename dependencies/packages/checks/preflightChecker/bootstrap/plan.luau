-- dependencies/packages/checks/preflightChecker/bootstrap/plan.luau
--!strict

const Bootstrap = require("@ci/bootstrap")
const Json = require("@formats/json")
const Process = require("@lute/process")

const event = Process.args[2]
if event ~= "push" and event ~= "pull_request" and event ~= "workflow_dispatch" then
	error("Expected push, pull_request, or workflow_dispatch", 0)
end

print(Json.encode(Bootstrap.new(event):BuildPlan()))

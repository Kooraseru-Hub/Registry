-- dependencies/packages/core/hostRunner/run.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Toml = require("@formats/toml")

const selector = Process.args[2]
const selected = if selector == "--" then Process.args[3] else selector
if not selected or not selected:match("^[%w_-]+$") then
	error("usage: lute run dependencies/packages/core/hostRunner/run.luau <host-name>", 0)
end

const contractPath = `source/hosts/{selected}/host.toml`
if not Fs.exists(contractPath) or Fs.metadata(contractPath).type ~= "file" then
	error(`unknown host {selected}; no contract at {contractPath}`, 0)
end
const decodedContract = Toml.decode(Fs.readFileToString(contractPath))
if type(decodedContract) ~= "table" then
	error(`invalid host contract: {contractPath}`, 0)
end
const contract = decodedContract :: { [string]: unknown }
if type(contract.artifacts) ~= "table" then
	error(`invalid host contract: {contractPath}`, 0)
end
const artifacts = contract.artifacts :: { string }
if #artifacts == 0 then
	error(`host contract has no artifacts: {contractPath}`, 0)
end

for _, artifact in artifacts do
	if not Fs.exists(artifact) or Fs.metadata(artifact).type ~= "file" then
		error(
			`missing {artifact}; build first with node dependencies/packages/core/dependencyLoader/index.ts --exec tools.ciEngine native`,
			0
		)
	end
end

const executable = contract.run

if executable == nil then
	print(`Host {selected} produced {#artifacts} artifact(s); no run artifact is declared`)
	for _, artifact in artifacts do
		print(artifact)
	end
	return
end

if type(executable) ~= "string" or not table.find(artifacts, executable) then
	error(`host run artifact is not declared by {contractPath}`, 0)
end

const options: Process.ProcessRunOptions = {
	cwd = Process.cwd(),
	stdio = "inherit",
}
const result = Process.run({ executable }, options)
if not result.ok then
	Process.exit(result.exitcode)
end

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "../../..");
const escape = text => text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

function instance(node) {
    let properties = `<string name="Name">${escape(node.name)}</string>`;
    if (node.className === "ModuleScript") {
        if (node.filePaths.length !== 1) throw new Error(`Expected one source file for ${node.name}`);
        const source = fs.realpathSync(path.resolve(root, node.filePaths[0]));
        const relative = path.relative(fs.realpathSync(root), source);
        if (path.isAbsolute(relative) || relative.startsWith(".." + path.sep)) throw new Error("Source escapes the repository");
        properties += `<ProtectedString name="Source">${escape(fs.readFileSync(source, "utf8").replace(/^\uFEFF/, ""))}</ProtectedString>`;
    }
    const children = (node.children || []).map(instance).join("");
    return `<Item class="${escape(node.className)}"><Properties>${properties}</Properties>${children}</Item>`;
}

function build(output) {
    execFileSync(process.execPath, [".vscode/config/luau/generate-sourcemap.cjs"], { cwd: root });
    const { children: services } = JSON.parse(fs.readFileSync(path.join(root, "sourcemap.json"), "utf8"));
    const workspace = '<Item class="Workspace"><Properties><string name="Name">Workspace</string><token name="UseNewLuauTypeSolver">2</token></Properties></Item>';
    const document = body => `<roblox version="4"><External>null</External><External>nil</External>${body}</roblox>`;
    fs.mkdirSync(output, { recursive: true });
    fs.writeFileSync(path.join(output, "Registry.rbxlx"), document(workspace + services.map(instance).join("")));
    fs.writeFileSync(path.join(output, "Registry.rbxmx"), document(services.flatMap(service => service.children).map(instance).join("")));
}

if (require.main === module) build(process.argv[2] || path.join(root, "build/artifacts/tests/studio"));
module.exports = { build };

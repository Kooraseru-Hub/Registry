const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../../..");

function mapEntry(relativePath, name) {
    const absolutePath = path.join(root, relativePath);
    if (fs.statSync(absolutePath).isFile()) {
        return { name, className: "ModuleScript", filePaths: [relativePath] };
    }

    const head = relativePath + "/init.luau";
    const hasHead = fs.existsSync(path.join(root, head));
    const children = fs.readdirSync(absolutePath, { withFileTypes: true })
        .sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0)
        .filter(entry => entry.isDirectory() || (entry.name.endsWith(".luau") && entry.name !== "init.luau"))
        .map(entry => mapEntry(relativePath + "/" + entry.name, entry.name.replace(/\.luau$/, "")))
        .filter(entry => entry.className !== "Folder" || entry.children.length > 0);

    const names = new Set();
    for (const child of children) {
        if (names.has(child.name)) {
            throw new Error(`Duplicate DataModel child "${child.name}" under ${relativePath}`);
        }
        names.add(child.name);
    }

    return {
        name,
        className: hasHead ? "ModuleScript" : "Folder",
        ...(hasHead ? { filePaths: [head] } : {}),
        children,
    };
}

const aliases = require("../../../tests/registry/Studio/aliases.json");
const storage = { name: "ReplicatedStorage", className: "ReplicatedStorage", children: [] };
for (const [alias, source] of Object.entries(aliases)) {
    const segments = alias.split("/");
    if (segments.length < 3 || segments[0] !== "@game" || segments[1] !== storage.name ||
        segments.slice(2).some(name => !name || name === "." || name === "..")) {
        throw new Error("Expected an alias under @game/ReplicatedStorage: " + alias);
    }
    const name = segments.pop();
    let parent = storage;
    for (const segment of segments.slice(2)) {
        let folder = parent.children.find(child => child.name === segment);
        if (!folder) {
            folder = { name: segment, className: "Folder", children: [] };
            parent.children.push(folder);
        }
        if (folder.className !== "Folder") throw new Error("Alias overlaps a module: " + alias);
        parent = folder;
    }
    if (parent.children.some(child => child.name === name)) throw new Error("Alias overlaps an existing mount: " + alias);
    parent.children.push(mapEntry(source, name));
}

const map = { name: "game", className: "DataModel", children: [storage] };

fs.writeFileSync(path.join(root, "sourcemap.json"), JSON.stringify(map, null, 2) + "\n");

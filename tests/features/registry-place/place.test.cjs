const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { build } = require("../../registry/Studio/build.cjs");

const root = path.resolve(__dirname, "../../..");
const registryTests = path.join(root, "tests/registry");
const entities = { amp: "&", lt: "<", gt: ">", quot: '"' };
const decode = value => value.replace(/&(amp|lt|gt|quot);/g, (_, entity) => entities[entity]);
const normalizeSource = value => value.replace(/^\uFEFF/, "").replaceAll("\r\n", "\n").replace(/\n+$/, "");

// Parse the restricted XML shape emitted by the fixture builder.
function readItems(xml) {
    assert.match(xml, /^<roblox version="4">.*<\/roblox>$/s);
    const rootItem = { children: new Map() };
    const stack = [rootItem];
    const tags = /<Item class="([^"]+)"><Properties><string name="Name">([^<]*)<\/string>(?:<ProtectedString name="Source">([^<]*)<\/ProtectedString>|<token name="UseNewLuauTypeSolver">2<\/token>)?<\/Properties>|<\/Item>/g;
    let end = '<roblox version="4"><External>null</External><External>nil</External>'.length;
    for (const tag of xml.matchAll(tags)) {
        assert.equal(tag.index, end, "Unexpected XML between instances");
        end = tag.index + tag[0].length;
        const [, kind, name, source] = tag;
        if (!kind) {
            assert.ok(stack.length > 1, "Unexpected item closing tag");
            stack.pop();
            continue;
        }
        const children = stack.at(-1).children;
        const key = decode(name);
        assert.ok(!children.has(key), `Duplicate instance ${key}`);
        const item = { kind, source: source === undefined ? undefined : decode(source), children: new Map() };
        children.set(key, item);
        stack.push(item);
    }
    assert.equal(stack.length, 1, "Unclosed item");
    assert.equal(xml.slice(end), "</roblox>");
    return rootItem.children;
}

function verifySource(item, file) {
    assert.equal(item?.kind, "ModuleScript", file);
    assert.equal(normalizeSource(item.source), normalizeSource(fs.readFileSync(file, "utf8")), file);
}

function verifyDirectory(item, directory) {
    const expected = fs.readdirSync(directory, { withFileTypes: true }).filter(entry =>
        entry.isDirectory()
            ? fs.readdirSync(path.join(directory, entry.name), { recursive: true }).some(file => file.endsWith(".luau"))
            : entry.name.endsWith(".luau") && entry.name !== "init.luau");
    assert.deepEqual([...item.children.keys()].sort(), expected.map(entry =>
        entry.isDirectory() ? entry.name : path.basename(entry.name, ".luau")).sort(), directory);
    for (const entry of expected) {
        const file = path.join(directory, entry.name);
        const child = item.children.get(entry.isDirectory() ? entry.name : path.basename(entry.name, ".luau"));
        if (entry.isDirectory()) {
            const head = path.join(file, "init.luau");
            if (fs.existsSync(head)) verifySource(child, head);
            else assert.equal(child?.kind, "Folder", file);
            verifyDirectory(child, file);
        } else {
            verifySource(child, file);
        }
    }
}

function verifyStorage(items) {
    verifySource(items.get("Registry"), path.join(root, "source/Registry.luau"));
    const tests = items.get("tests");
    const registry = tests?.children.get("registry");
    assert.equal(tests?.kind, "Folder");
    assert.equal(registry?.kind, "Folder");
    verifyDirectory(registry, registryTests);
    const benchmarks = items.get("benchmarks");
    const workloads = benchmarks?.children.get("registry");
    assert.equal(benchmarks?.kind, "Folder");
    assert.equal(workloads?.kind, "Folder");
    verifyDirectory(workloads, path.join(root, "benchmarks/registry"));
}

test("Registry test place matches its source tree", () => {
    const output = fs.mkdtempSync(path.join(os.tmpdir(), "registry-place-"));
    try {
        build(output);
        const place = readItems(fs.readFileSync(path.join(output, "Registry.rbxlx"), "utf8"));
        const storage = place.get("ReplicatedStorage");
        assert.equal(storage?.kind, "ReplicatedStorage");
        verifyStorage(storage.children);
        verifyStorage(readItems(fs.readFileSync(path.join(output, "Registry.rbxmx"), "utf8")));
    } finally {
        fs.rmSync(output, { recursive: true, force: true });
    }
});

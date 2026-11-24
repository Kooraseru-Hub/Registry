"use strict";

// Minimal uncompressed Roblox binary model writer for Folder and ModuleScript.
// Format: https://dom.rojo.space/binary.html
const fs = require("node:fs");
const { execFileSync } = require("node:child_process");

const bytes = (...parts) => Buffer.concat(parts);
function u32(value) {
    const result = Buffer.alloc(4);
    result.writeUInt32LE(value);
    return result;
}
function string(value) {
    const data = Buffer.isBuffer(value) ? value : Buffer.from(value, "utf8");
    return bytes(u32(data.length), data);
}
function references(values) {
    const data = Buffer.alloc(values.length * 4);
    let previous = 0;
    values.forEach((value, index) => {
        const delta = value - previous;
        previous = value;
        const encoded = ((delta << 1) ^ (delta >> 31)) >>> 0;
        for (let byte = 0; byte < 4; byte++) {
            data[byte * values.length + index] = (encoded >>> (24 - byte * 8)) & 255;
        }
    });
    return data;
}
function chunk(name, payload) {
    return bytes(Buffer.from(name, "ascii"), u32(0), u32(payload.length), u32(0), payload);
}
function git(args) {
    return execFileSync("git", args, { maxBuffer: 32 * 1024 * 1024 });
}
function readTree(commit, source) {
    const root = { name: "Registry", children: new Map() };
    const load = file => git(["show", commit + ":" + file]);
    if (/\.luau?$/.test(source)) {
        root.source = load(source);
        return root;
    }
    const listing = git(["ls-tree", "-r", "--name-only", "-z", commit, "--", source])
        .toString("utf8").split("\0").filter(Boolean);
    for (const file of listing) {
        if (!/\.luau?$/.test(file)) continue;
        const parts = file.slice(source.length + 1).split("/");
        const name = parts.pop().replace(/\.luau?$/, "");
        let node = root;
        for (const part of parts) {
            if (!node.children.has(part)) node.children.set(part, { name: part, children: new Map() });
            node = node.children.get(part);
        }
        if (name !== "init") {
            if (!node.children.has(name)) node.children.set(name, { name, children: new Map() });
            node = node.children.get(name);
        }
        if (node.source !== undefined) throw new Error("Duplicate ModuleScript: " + file);
        node.source = load(file);
    }
    if (root.source === undefined) throw new Error("Registry root must be a ModuleScript");
    return root;
}
function encode(root) {
    const instances = [];
    const postorder = [];
    function visit(node, parent) {
        const instance = { ...node, id: instances.length, parent };
        instances.push(instance);
        for (const child of node.children.values()) visit(child, instance.id);
        postorder.push(instance);
    }
    visit(root, -1);
    const groups = ["Folder", "ModuleScript"].map(name => ({
        name,
        instances: instances.filter(node => (node.source === undefined ? "Folder" : "ModuleScript") === name),
    })).filter(group => group.instances.length);
    const header = bytes(Buffer.from("<roblox!", "ascii"), Buffer.from([0x89, 0xff, 13, 10, 26, 10, 0, 0]),
        u32(groups.length), u32(instances.length), Buffer.alloc(8));
    const definitions = groups.map((group, id) => chunk("INST", bytes(u32(id), string(group.name),
        Buffer.from([0]), u32(group.instances.length), references(group.instances.map(node => node.id)))));
    const properties = [];
    for (const [id, group] of groups.entries()) {
        const property = (name, values) => chunk("PROP", bytes(u32(id), string(name), Buffer.from([1]), ...values.map(string)));
        properties.push(property("Name", group.instances.map(node => node.name)));
        if (group.name === "ModuleScript") properties.push(property("Source", group.instances.map(node => node.source)));
    }
    return bytes(header, ...definitions, ...properties,
        chunk("PRNT", bytes(Buffer.from([0]), u32(instances.length),
            references(postorder.map(node => node.id)), references(postorder.map(node => node.parent)))),
        chunk("END\0", Buffer.from("</roblox>", "ascii")));
}
if (require.main === module) {
    const [commit, source, output] = process.argv.slice(2);
    if (!/^[a-f0-9]{40}$/.test(commit || "") || !source || !output) throw new Error("Expected commit, source and output");
    fs.writeFileSync(output, encode(readTree(commit, source)));
}
module.exports = { encode, readTree };

"""Build Studio-test assets from the same alias map as luau-lsp."""

import json
from pathlib import Path
import subprocess
import sys
from xml.etree import ElementTree as XML

ROOT = Path(__file__).resolve().parents[3]


def instance(parent, node):
    item = XML.SubElement(parent, "Item", {"class": node["className"]})
    properties = XML.SubElement(item, "Properties")
    XML.SubElement(properties, "string", name="Name").text = node["name"]
    if node["className"] == "ModuleScript":
        sources = node["filePaths"]
        if len(sources) != 1:
            raise ValueError(f"Expected one source file for {node['name']}")
        source = (ROOT / sources[0]).resolve()
        if not source.is_relative_to(ROOT):
            raise ValueError(f"Source escapes the repository: {source}")
        XML.SubElement(properties, "ProtectedString", name="Source").text = source.read_text(encoding="utf-8-sig")
    for child in node.get("children", []):
        instance(item, child)


def document():
    root = XML.Element("roblox", version="4")
    for value in ("null", "nil"):
        XML.SubElement(root, "External").text = value
    return root


def build(output):
    subprocess.run(["node", ".vscode/config/luau/generate-sourcemap.cjs"], cwd=ROOT, check=True)
    mapping = json.loads((ROOT / "sourcemap.json").read_text(encoding="utf-8"))
    place = document()
    workspace = XML.SubElement(place, "Item", {"class": "Workspace"})
    properties = XML.SubElement(workspace, "Properties")
    XML.SubElement(properties, "string", name="Name").text = "Workspace"
    XML.SubElement(properties, "token", name="UseNewLuauTypeSolver").text = "2"
    model = document()
    for service in mapping["children"]:
        instance(place, service)
        for node in service["children"]:
            instance(model, node)
    output.mkdir(parents=True, exist_ok=True)
    for root, name in [(place, "Registry.rbxlx"), (model, "Registry.rbxmx")]:
        XML.ElementTree(root).write(output / name, encoding="utf-8", xml_declaration=False)


if __name__ == "__main__":
    build(Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "build" / "studio")

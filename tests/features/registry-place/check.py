"""Check the Studio test place as XML without starting Roblox Studio."""

from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[3]
TESTS = ROOT / "tests" / "registry"


def named_children(parent):
    children = {}
    for item in parent.findall("Item"):
        name = item.findtext("Properties/string[@name='Name']")
        if name is None:
            continue
        if name in children:
            raise ValueError(f"Duplicate instance named {name}")
        children[name] = item
    return children


def check_module(item, file):
    if item.get("class") != "ModuleScript":
        raise ValueError(f"{file.relative_to(ROOT)} is not a ModuleScript in the place")
    embedded = item.findtext("Properties/ProtectedString[@name='Source']")
    if embedded is None or embedded.replace("\r\n", "\n").rstrip("\n") != file.read_text(encoding="utf-8-sig").rstrip("\n"):
        raise ValueError(f"Source differs in the place for {file.relative_to(ROOT)}")


def check_directory(item, directory):
    expected = {
        child.name if child.is_dir() else child.stem: child
        for child in directory.iterdir()
        if child.name != "init.luau"
        and (child.suffix == ".luau" or (child.is_dir() and any(child.rglob("*.luau"))))
    }
    children = named_children(item)
    if set(children) != set(expected):
        missing = sorted(expected.keys() - children.keys())
        extra = sorted(children.keys() - expected.keys())
        raise ValueError(f"{directory.relative_to(ROOT)} differs in the place: missing {missing}, extra {extra}")
    for name, child in expected.items():
        if child.is_file():
            check_module(children[name], child)
            continue
        entry = child / "init.luau"
        if entry.is_file():
            check_module(children[name], entry)
        elif children[name].get("class") != "Folder":
            raise ValueError(f"{child.relative_to(ROOT)} is not a Folder in the place")
        check_directory(children[name], child)


def main():
    with TemporaryDirectory() as temporary:
        output = Path(temporary)
        subprocess.run([sys.executable, str(TESTS / "Studio" / "build.py"), str(output)], check=True)
        check_place(output / "Registry.rbxlx")
        model = ElementTree.parse(output / "Registry.rbxmx").getroot()
        check_storage(model)


def check_place(file):
    place = ElementTree.parse(file).getroot()
    if place.tag != "roblox" or place.get("version") != "4":
        raise ValueError("Expected Roblox place XML, version 4")
    shared = place.find("Item[@class='ReplicatedStorage']")
    if shared is None:
        raise ValueError("ReplicatedStorage is missing")
    check_storage(shared)


def check_storage(shared):
    children = named_children(shared)
    check_module(children["Registry"], ROOT / "source" / "Registry.luau")
    test_container = children["tests"]
    test_group = named_children(test_container)["registry"]
    if any(item.get("class") != "Folder" for item in (test_container, test_group)):
        raise ValueError("ReplicatedStorage.tests.registry must be a folder hierarchy")
    check_directory(test_group, TESTS)
    print("Registry test place hierarchy and embedded Luau match disk")


if __name__ == "__main__":
    main()

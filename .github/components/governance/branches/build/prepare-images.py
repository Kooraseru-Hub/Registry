#!/usr/bin/env python3
"""Download original ShieldCN artwork and sanitize static SVGs."""
import json
import re
import sys
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", XLINK)
MAX_BYTES = 8 * 1024 * 1024
ALLOWED = set("""svg g defs title desc path rect circle ellipse line polyline polygon
text tspan textPath linearGradient radialGradient stop clipPath mask pattern
symbol use image filter feGaussianBlur feOffset feColorMatrix feBlend
feComposite feFlood feMerge feMergeNode feDropShadow feComponentTransfer
feFuncR feFuncG feFuncB feFuncA feMorphology""".split())
FRAGMENT = re.compile(r"#[A-Za-z0-9_.:-]+\Z")
CSS_URL = re.compile(r"url\s*\(\s*(['\"]?)(.*?)\1\s*\)", re.I)


def sanitize(data):
    if len(data) > MAX_BYTES or re.search(rb"<!\s*(?:DOCTYPE|ENTITY)", data, re.I):
        raise ValueError("Unsafe SVG size or declaration")
    root = ET.fromstring(data)
    if root.tag != f"{{{SVG}}}svg":
        raise ValueError("Expected an SVG root")
    for node in root.iter():
        if not node.tag.startswith(f"{{{SVG}}}") or node.tag.split("}", 1)[1] not in ALLOWED:
            raise ValueError(f"Unsupported SVG element: {node.tag}")
        for attr, value in list(node.attrib.items()):
            name = attr.rsplit("}", 1)[-1].lower()
            if name.startswith("on"):
                del node.attrib[attr]
                continue
            if name == "href":
                # Local references only; static raster data is safe to preserve.
                if not FRAGMENT.fullmatch(value) and not (
                    node.tag == f"{{{SVG}}}image"
                    and re.fullmatch(r"data:image/(?:png|jpeg|webp);base64,[A-Za-z0-9+/=]+", value)
                ):
                    raise ValueError("External or unsupported SVG reference")
            if name in {"src", "base"} or re.search(r"javascript\s*:|@import|expression\s*\(", value, re.I):
                raise ValueError(f"Unsafe SVG attribute: {attr}")
            if name == "style" and ("\\" in value or "/*" in value or "@" in value):
                raise ValueError("Unsupported CSS syntax")
            for match in CSS_URL.finditer(value):
                if not FRAGMENT.fullmatch(match.group(2)):
                    raise ValueError("External SVG CSS reference")
            if re.search(r"url\s*\(", CSS_URL.sub("", value), re.I):
                raise ValueError("Invalid SVG CSS reference")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def badges(destination):
    manifest = json.loads(Path("content/images/badges/sources.json").read_text(encoding="utf-8"))
    destination.mkdir(parents=True, exist_ok=True)
    for name, url in manifest.items():
        parsed = urllib.parse.urlsplit(url)
        if not re.fullmatch(r"[a-z]+", name) or parsed.scheme != "https" or parsed.netloc != "shieldcn.dev":
            raise ValueError("Invalid badge source")
        existing = Path("content/images/badges") / (name + ".svg")
        if existing.is_file():
            data = existing.read_bytes()
        else:
            request = urllib.request.Request(url, headers={"Accept": "image/svg+xml", "User-Agent": "Registry README asset builder"})
            with urllib.request.urlopen(request, timeout=20) as response:
                if urllib.parse.urlsplit(response.geturl()).netloc != "shieldcn.dev":
                    raise ValueError("Unexpected badge redirect")
                data = response.read(MAX_BYTES + 1)
        (destination / (name + ".svg")).write_bytes(sanitize(data))


def charts(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    for method in ("require", "registry"):
        for phase in ("cold", "warm"):
            name = f"{method}-{phase}-matrix.svg"
            (destination / name).write_bytes(sanitize((source / name).read_bytes()))


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "badges":
        badges(Path(sys.argv[2]))
    elif len(sys.argv) == 4 and sys.argv[1] == "charts":
        charts(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        raise SystemExit("usage: prepare-images.py badges OUTPUT | charts SOURCE OUTPUT")

"""Check the actual sideload ZIP for missing components, scripts, and PNG assets."""
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile

archive = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/luma.zip")
errors = []
with zipfile.ZipFile(archive) as package:
    names = set(package.namelist())
    if "manifest" not in names:
        raise SystemExit("FAIL: manifest must be at the ZIP root")
    manifest = dict(line.split("=", 1) for line in package.read("manifest").decode().splitlines()
                    if "=" in line and not line.lstrip().startswith("#"))
    for field in ["title", "major_version", "minor_version", "build_version", "ui_resolutions"]:
        if not manifest.get(field):
            errors.append(f"Missing manifest field: {field}")
    for field, value in manifest.items():
        if value.startswith("pkg:/") and value[5:] not in names:
            errors.append(f"Missing manifest asset: {value}")
    components = {}
    for name in names:
        if name.endswith(".brs"):
            # A component function named RunService silently aborts foreground
            # startup on the G510X/OS 16.0.4, even with an empty body. The
            # desktop compiler/emulator do not catch this native name collision.
            if re.search(r"(?im)^\s*(?:sub|function)\s+RunService\s*\(",
                         package.read(name).decode("utf-8-sig")):
                errors.append(f"Roku startup-incompatible function name RunService in {name}; use an app-specific Task function name")
        if name.endswith(".xml"):
            try:
                root = ET.fromstring(package.read(name))
            except ET.ParseError as error:
                errors.append(f"Invalid XML {name}: {error}")
                continue
            component = root.get("name")
            if component in components:
                errors.append(f"Duplicate component {component}: {name}")
            components[component] = name
            for element in root.iter():
                for value in element.attrib.values():
                    if value.startswith("pkg:/") and value[5:] not in names:
                        errors.append(f"Missing reference in {name}: {value}")
        if name.endswith(".png"):
            data = package.read(name)
            if data[:8] != b"\x89PNG\r\n\x1a\n":
                errors.append(f"Invalid PNG: {name}")
            else:
                width, height = struct.unpack(">II", data[16:24])
                if not width or not height:
                    errors.append(f"Empty PNG: {name}")
        if any(part in {".local", "node_modules", ".git", ".env"} for part in PurePosixPath(name).parts):
            errors.append(f"Development/private file in channel: {name}")
    if not any(name.startswith("source/") and name.endswith(".brs") for name in names):
        errors.append("Missing BrightScript entry point")

if errors:
    raise SystemExit("\n".join("FAIL: " + error for error in errors))
print(f"PASS: {archive} — {len(names)} entries; {len(components)} XML components; scripts/assets present")

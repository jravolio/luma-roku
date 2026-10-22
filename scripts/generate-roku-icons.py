#!/usr/bin/env python3
"""Rasterize app-owned web icon geometry for Roku. Run with CairoSVG + Cairo.

On Homebrew macOS: DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib python3 scripts/generate-roku-icons.py
--check needs only Python's standard library and detects source/asset drift.
"""
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'preview/src/components/icons.tsx'
OUTPUT = ROOT / 'roku/images/icons'
ICONS = ['Play', 'Pause', 'Audio', 'Subtitles', 'Gear', 'List', 'Check', 'Home', 'Film', 'Tv', 'Search']
SIZE = 48


def source_svg(name):
    source = SOURCE.read_text()
    match = re.search(r'export const ' + name + r'Icon = .*?<Icon \{\.\.\.p\}>(.*?)</Icon>', source, re.S)
    if not match:
        raise ValueError(f'Missing web icon: {name}')
    body = match[1].strip()
    for jsx, svg in [('strokeWidth', 'stroke-width'), ('strokeLinecap', 'stroke-linecap'), ('strokeLinejoin', 'stroke-linejoin')]:
        body = body.replace(jsx, svg)
    if '{' in body or '<text' in body:
        raise ValueError(f'{name}: dynamic JSX/text needs explicit conversion support')
    wrapper = re.search(r'<svg\s+(.*?)>', source, re.S).group(1)
    attributes = dict(re.findall(r'(\w+)="([^"]*)"', wrapper))
    shared = []
    for attr in ['viewBox', 'fill', 'stroke', 'strokeWidth', 'strokeLinecap', 'strokeLinejoin']:
        key = re.sub(r'[A-Z]', lambda match: '-' + match[0].lower(), attr) if attr != 'viewBox' else attr
        shared.append(f'{key}="{attributes[attr].replace("currentColor", "white")}"')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" {" ".join(shared)}>{body.replace("currentColor", "white")}</svg>' 


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    check = '--check' in sys.argv
    manifest_path = OUTPUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if check else {}
    if not check:
        import cairosvg
        OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in ICONS:
        svg = source_svg(name).encode()
        target = OUTPUT / f'{name.lower()}.png'
        if not check:
            cairosvg.svg2png(bytestring=svg, write_to=str(target), output_width=SIZE, output_height=SIZE)
        record = {'export': name + 'Icon', 'size': SIZE, 'svgSha256': digest(svg), 'pngSha256': digest(target.read_bytes())}
        if check:
            if manifest.get(name.lower()) != record:
                raise SystemExit(f'Stale Roku icon: {name}; rerun scripts/generate-roku-icons.py')
        else:
            manifest[name.lower()] = record
    if not check:
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'{len(ICONS)} Roku icons {"verified" if check else "generated"} from web SVG geometry')


if __name__ == '__main__':
    main()

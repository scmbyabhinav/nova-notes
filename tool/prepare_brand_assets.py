#!/usr/bin/env python3
"""Rasterize the approved Orah SVG launcher mark for Android launcher assets."""
from pathlib import Path
import cairosvg

root = Path(__file__).resolve().parents[1]
source = root / "assets" / "orah_app_icon.svg"
target = root / "assets" / "app_icon.png"
if not source.is_file():
    raise SystemExit(f"Missing source launcher icon: {source}")
cairosvg.svg2png(url=str(source), write_to=str(target), output_width=512, output_height=512)
if not target.is_file() or target.stat().st_size < 1000:
    raise SystemExit("Launcher icon PNG generation failed.")
print(f"Generated {target} ({target.stat().st_size} bytes)")

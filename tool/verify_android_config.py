#!/usr/bin/env python3
"""Verify generated Android configuration meets the ORAH release target."""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--min-api", type=int, default=36)
args = parser.parse_args()

candidates = [ROOT / "android/app/build.gradle", ROOT / "android/app/build.gradle.kts"]
gradle = next((p for p in candidates if p.exists()), None)
if gradle is None:
    raise SystemExit("ERROR: Generated android/app/build.gradle(.kts) is missing.")

text = gradle.read_text()
def find_int(patterns):
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            return int(m.group(1))
    return None

target = find_int([r"targetSdk(?:Version)?\s*(?:=\s*)?(\d+)", r"targetSdkVersion\s*=\s*(\d+)"])
compile = find_int([r"compileSdk(?:Version)?\s*(?:=\s*)?(\d+)", r"compileSdk\s*=\s*(\d+)"])
if target is None:
    raise SystemExit("ERROR: target SDK is not explicitly configured in generated Gradle.")
if target < args.min_api:
    raise SystemExit(f"ERROR: target SDK {target} is below required API {args.min_api}.")
if compile is None:
    raise SystemExit("ERROR: compile SDK is not explicitly configured in generated Gradle.")
if compile < args.min_api:
    raise SystemExit(f"ERROR: compile SDK {compile} is below required API {args.min_api}.")
print(f"PASS: target SDK={target}, compile SDK={compile}, required minimum={args.min_api}.")

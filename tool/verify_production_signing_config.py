#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
gradle = ROOT / "android/app/build.gradle.kts"
props = ROOT / "key.properties"
keystore = ROOT / "android/app/orah-upload.jks"

if not gradle.exists():
    raise SystemExit("ERROR: Gradle file is missing.")
if not props.exists():
    raise SystemExit("ERROR: key.properties is missing.")
if not keystore.exists() or keystore.stat().st_size == 0:
    raise SystemExit("ERROR: production upload keystore is missing or empty.")

text = gradle.read_text()
for marker in ('create("release")', 'signingConfig = signingConfigs.getByName("release")'):
    if marker not in text:
        raise SystemExit(f"ERROR: release signing configuration missing: {marker}")
print("PASS: release build type explicitly uses the protected production upload key.")

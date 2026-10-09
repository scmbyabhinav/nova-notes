#!/usr/bin/env python3
"""Configure Android release signing idempotently for ORAH production builds."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
GRADLE_CANDIDATES = [
    ANDROID / "app" / "build.gradle.kts",
    ANDROID / "app" / "build.gradle",
]
PROPERTIES = ANDROID / "key.properties"
KEYSTORE = ANDROID / "orah-upload.jks"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_properties(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(("#", "!")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result


gradle = next((p for p in GRADLE_CANDIDATES if p.is_file()), None)
if gradle is None:
    fail("Android app Gradle file is missing (expected build.gradle.kts or build.gradle).")
if not PROPERTIES.is_file():
    fail(f"Signing properties file is missing: {PROPERTIES.relative_to(ROOT)}")
if not KEYSTORE.is_file() or KEYSTORE.stat().st_size == 0:
    fail(f"Upload keystore is missing or empty: {KEYSTORE.relative_to(ROOT)}")

props = load_properties(PROPERTIES)
required_properties = ("storePassword", "keyPassword", "keyAlias", "storeFile")
missing = [key for key in required_properties if not props.get(key)]
if missing:
    fail("Signing properties are missing required keys: " + ", ".join(missing))

# Resolve the keystore path the same way Gradle's rootProject.file(...) does.
store_file = (ANDROID / props["storeFile"]).resolve()
if not store_file.is_file() or store_file.stat().st_size == 0:
    fail("The storeFile specified in android/key.properties does not exist or is empty.")

text = gradle.read_text(encoding="utf-8")

if gradle.suffix == ".kts":
    properties_loader = '''    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = java.util.Properties()
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
'''
    release_signing_config = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

'''
    release_assignment = '            signingConfig = signingConfigs.getByName("release")'
    if "android {" not in text:
        fail("Missing android { } block in Gradle Kotlin DSL file.")

    has_release_config = 'create("release")' in text or 'getByName("release")' in text
    if has_release_config:
        if release_assignment not in text:
            # Do not silently accept a release config that is not attached to release.
            release_block = text.find("release {")
            if release_block < 0:
                fail("A release signing config exists, but the release buildType block is missing.")
            close = text.find("\n        }", release_block)
            if close < 0:
                fail("Could not safely locate the release buildType block.")
            text = text[:close] + "\n" + release_assignment + text[close:]
        if "keystorePropertiesFile" not in text:
            text = text.replace("android {", "android {\n" + properties_loader, 1)
        print("Existing release signing configuration found; verified and reused.")
    else:
        text = text.replace("android {", "android {\n" + properties_loader, 1)
        if "    buildTypes {" not in text:
            fail("Could not find buildTypes { } block to attach release signing.")
        text = text.replace("    buildTypes {", release_signing_config + "    buildTypes {", 1)
        release_block = text.find("        release {")
        if release_block < 0:
            fail("Could not find release { } build type block.")
        insert_at = release_block + len("        release {")
        text = text[:insert_at] + "\n" + release_assignment + text[insert_at:]
        print("Configured release signing.")
else:
    # Flutter's generated Groovy Gradle host has a different DSL. Fail safely
    # rather than writing Kotlin DSL into a Groovy file.
    fail("Generated Gradle file uses Groovy DSL; this signing configurator currently expects build.gradle.kts.")

# Validate the final file before writing it.
if 'signingConfig = signingConfigs.getByName("release")' not in text:
    fail("Release buildType is not wired to the release signing configuration.")
if "keystoreProperties" not in text or 'rootProject.file("key.properties")' not in text:
    fail("Gradle does not load android/key.properties from the Android project root.")

gradle.write_text(text, encoding="utf-8")
print("PASS: production signing configuration is present and wired to the release build.")

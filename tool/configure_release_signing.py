#!/usr/bin/env python3
"""Configure Android release signing idempotently for ORAH production builds."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
GRADLE_CANDIDATES = [ANDROID / "app" / "build.gradle.kts", ANDROID / "app" / "build.gradle"]
PROPERTIES = ANDROID / "key.properties"
KEYSTORE = ANDROID / "orah-upload.jks"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_properties(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(("#", "!")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


gradle = next((path for path in GRADLE_CANDIDATES if path.is_file()), None)
if gradle is None:
    fail("Android app Gradle file not found.")
if not PROPERTIES.is_file():
    fail("android/key.properties is missing.")
if not KEYSTORE.is_file() or KEYSTORE.stat().st_size == 0:
    fail("android/orah-upload.jks is missing or empty.")

props = load_properties(PROPERTIES)
required = ("storePassword", "keyPassword", "keyAlias", "storeFile")
missing = [key for key in required if not props.get(key)]
if missing:
    fail("Missing signing properties: " + ", ".join(missing))

store_file = (ANDROID / props["storeFile"]).resolve()
if not store_file.is_file() or store_file.stat().st_size == 0:
    fail("The keystore path configured by storeFile does not exist or is empty.")

text = gradle.read_text(encoding="utf-8")
if gradle.name.endswith(".kts"):
    # Avoid java.util resolution failures in Kotlin DSL: import Properties at
    # script top level and refer to Properties() inside the Android block.
    if "import java.util.Properties" not in text:
        text = "import java.util.Properties\n" + text
    loader = '''    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
'''
    config = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

'''
    assignment = '            signingConfig = signingConfigs.getByName("release")'
    if "android {" not in text:
        fail("Missing android { } block in Kotlin Gradle script.")

    has_release_config = 'create("release")' in text or 'getByName("release")' in text
    if "keystorePropertiesFile" not in text:
        text = text.replace("android {", "android {\n" + loader, 1)

    if not has_release_config:
        if "    buildTypes {" not in text:
            fail("Could not find buildTypes { } block.")
        text = text.replace("    buildTypes {", config + "    buildTypes {", 1)

    # Flutter's generated release build type can contain a later debug signing
    # assignment. If we merely prepend the production assignment, that later
    # assignment overrides it and the AAB is still signed with the debug key.
    start = text.find("        release {")
    if start < 0:
        fail("Could not find release { } build type block.")
    end = text.find("\n        }", start + len("        release {"))
    if end < 0:
        fail("Could not find the end of the release build type block.")

    release_block = text[start:end]
    release_lines = release_block.splitlines()
    release_lines = [
        line for line in release_lines
        if not ("signingConfig =" in line and 'getByName("debug")' in line)
    ]
    assignment_indexes = [
        index for index, line in enumerate(release_lines)
        if line.strip() == assignment.strip()
    ]
    if not assignment_indexes:
        release_lines.insert(1, assignment)
    else:
        # Keep exactly one production signing assignment.
        first = assignment_indexes[0]
        release_lines = [
            line for index, line in enumerate(release_lines)
            if line.strip() != assignment.strip() or index == first
        ]

    updated_release_block = "\n".join(release_lines)
    text = text[:start] + updated_release_block + text[end:]

    if assignment not in text or "keystorePropertiesFile" not in text:
        fail("Could not verify release signing is wired to key.properties.")
    final_release_start = text.find("        release {")
    final_release_end = text.find("\n        }", final_release_start + len("        release {"))
    final_release_block = text[final_release_start:final_release_end]
    if 'signingConfig = signingConfigs.getByName("debug")' in final_release_block:
        fail("Debug signing still overrides the production release signing config.")
    if final_release_block.count(assignment) != 1:
        fail("Expected exactly one production signing assignment in release build type.")
    gradle.write_text(text, encoding="utf-8")
    print("PASS: release signing configuration is present and wired to the upload keystore.")
else:
    fail("Expected build.gradle.kts; refusing to write Kotlin DSL into a Groovy Gradle file.")

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

    if assignment not in text:
        # Only insert the signing assignment into the release buildType block.
        start = text.find("        release {")
        if start < 0:
            fail("Could not find release { } build type block.")
        insert_at = start + len("        release {")
        text = text[:insert_at] + "\n" + assignment + text[insert_at:]

    if assignment not in text or "keystorePropertiesFile" not in text:
        fail("Could not verify release signing is wired to key.properties.")
    gradle.write_text(text, encoding="utf-8")
    print("PASS: release signing configuration is present and wired to the upload keystore.")
else:
    fail("Expected build.gradle.kts; refusing to write Kotlin DSL into a Groovy Gradle file.")

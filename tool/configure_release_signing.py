#!/usr/bin/env python3
"""Configure the generated Android Gradle file for production release signing.

The workflow creates android/key.properties and android/orah-upload.jks before
calling this script. Keep this operation idempotent so a generated Gradle file
that already contains the release signing block does not fail the build.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
gradle = root / "android" / "app" / "build.gradle.kts"
properties = root / "android" / "key.properties"
keystore = root / "android" / "orah-upload.jks"

for required in (gradle, properties, keystore):
    if not required.is_file():
        raise SystemExit(f"Required production-signing file is missing: {required}")

text = gradle.read_text(encoding="utf-8")

properties_marker = 'val keystorePropertiesFile = rootProject.file("key.properties")'
release_config_marker = 'create("release")'
release_assignment = 'signingConfig = signingConfigs.getByName("release")'

# A repeat run should succeed when this script has already configured Gradle.
if properties_marker in text and release_config_marker in text and release_assignment in text:
    print("Release signing is already configured.")
    sys.exit(0)

if "android {" not in text:
    raise SystemExit(f"Missing android {{ }} block in {gradle}")
if "    buildTypes {" not in text:
    raise SystemExit(f"Missing buildTypes {{ }} block in {gradle}")
if "        release {" not in text:
    raise SystemExit(f"Missing release build type in {gradle}")

properties_block = '''android {
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = java.util.Properties()
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }
'''
text = text.replace("android {", properties_block, 1)

signing_block = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

'''
text = text.replace("    buildTypes {", signing_block + "    buildTypes {", 1)

# Flutter's generated template signs release builds with the debug key by
# default. Replace only that template assignment with the production config.
debug_assignment = 'signingConfig = signingConfigs.getByName("debug")'
if debug_assignment in text:
    text = text.replace(debug_assignment, release_assignment, 1)
elif release_assignment not in text:
    raise SystemExit(
        "Could not find Flutter's default debug signing assignment or an existing "
        "release signing assignment in the release build type."
    )

gradle.write_text(text, encoding="utf-8")
print("Configured production release signing in android/app/build.gradle.kts.")

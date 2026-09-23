#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
gradle = root / "android/app/build.gradle.kts"
t = gradle.read_text()
if "signingConfigs" in t: raise SystemExit("Release signing already configured.")
if "android {" not in t: raise SystemExit("Missing android block.")
t = t.replace("android {", 'android {\n    val keystorePropertiesFile = rootProject.file("key.properties")\n    val keystoreProperties = java.util.Properties()\n    if (keystorePropertiesFile.exists()) {\n        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }\n    }\n', 1)
t = t.replace("    buildTypes {", '    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties["keyAlias"] as String?\n            keyPassword = keystoreProperties["keyPassword"] as String?\n            storeFile = (keystoreProperties["storeFile"] as String?)?.let { rootProject.file(it) }\n            storePassword = keystoreProperties["storePassword"] as String?\n        }\n    }\n\n    buildTypes {', 1)
t = t.replace("        release {", '        release {\n            signingConfig = signingConfigs.getByName("release")', 1)
gradle.write_text(t)
print("Configured release signing.")
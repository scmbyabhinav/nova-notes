#!/usr/bin/env python3
"""Static release-readiness audit for the generated Android host workflow.

This runs before the Android host is generated, so it checks source-of-truth
configuration only. It intentionally reports missing Play Console setup
instead of inventing credentials, signing keys, or public URLs.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
warnings = []

pubspec = (ROOT / "pubspec.yaml").read_text()
version_match = re.search(r"^version:\s*([^\s]+)", pubspec, re.MULTILINE)
if not version_match or not re.fullmatch(r"\d+\.\d+\.\d+\+\d+", version_match.group(1)):
    errors.append("pubspec.yaml must contain a semantic version with build number, e.g. 1.0.0+1.")

version_file = ROOT / "VERSION"
if version_file.exists():
    version_text = version_file.read_text().strip()
    if version_match and version_text != version_match.group(1):
        errors.append(f"VERSION ({version_text}) does not match pubspec.yaml ({version_match.group(1)}).")
else:
    errors.append("VERSION file is missing.")

entitlement = (ROOT / "lib/services/orah_entitlement_service.dart").read_text()
required_products = {
    "monthlyId": "orah_pro_monthly",
    "yearlyId": "orah_pro_yearly",
    "lifetimeId": "orah_pro_lifetime",
}
for symbol, product_id in required_products.items():
    if f"static const {symbol} = '{product_id}';" not in entitlement:
        errors.append(f"Missing billing product ID: {symbol} -> {product_id}")

listing = ROOT / "PLAY_STORE_LISTING.md"
if listing.exists() and "NOVA Notes" in listing.read_text():
    errors.append("PLAY_STORE_LISTING.md still contains the old NOVA Notes product name.")

checklist = ROOT / "RELEASE_CHECKLIST.md"
if checklist.exists() and "NOVA Notes" in checklist.read_text():
    errors.append("RELEASE_CHECKLIST.md still contains the old NOVA Notes product name.")

workflow = ROOT / ".github/workflows/nova-android-ci.yml"
if not workflow.exists():
    errors.append("Android CI workflow is missing.")
else:
    workflow_text = workflow.read_text()
    for required in ("flutter analyze", "flutter test", "flutter build apk --release", "flutter build appbundle --release"):
        if required not in workflow_text:
            errors.append(f"Android CI is missing required step: {required}")

if not (ROOT / "PRIVACY_POLICY.md").exists():
    warnings.append("PRIVACY_POLICY.md is not present; a public privacy-policy URL is still required before Play production release.")

print("ORAH release audit")
print("=================")
if errors:
    print("\nERRORS")
    for item in errors:
        print(f"- {item}")
if warnings:
    print("\nWARNINGS")
    for item in warnings:
        print(f"- {item}")
if not errors and not warnings:
    print("PASS: source configuration checks are clean.")
elif not errors:
    print("\nPASS WITH WARNINGS: no blocking source-configuration errors found.")

sys.exit(1 if errors else 0)

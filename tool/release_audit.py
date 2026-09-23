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

android_host = ROOT / "tool/prepare_android_host.py"
if not android_host.exists():
    errors.append("Android host preparation script is missing.")
else:
    host_text = android_host.read_text()
    required_host_markers = (
        "package com.orah.orah_notes",
        "class MainActivity",
        "OrahQuickWidgetProvider",
        "android.app.shortcuts",
        "android.intent.action.SEND",
        "android.intent.action.SEND_MULTIPLE",
    )
    for marker in required_host_markers:
        if marker not in host_text:
            errors.append(f"Android host preparation is missing required marker: {marker}")

workflow = ROOT / ".github/workflows/nova-android-ci.yml"
if not workflow.exists():
    errors.append("Android CI workflow is missing.")
else:
    workflow_text = workflow.read_text()
    for required in ("flutter analyze", "flutter test", "flutter build apk --release", "flutter build appbundle --release"):
        if required not in workflow_text:
            errors.append(f"Android CI is missing required step: {required}")

privacy = ROOT / "PRIVACY_POLICY.md"
if not privacy.exists():
    warnings.append("PRIVACY_POLICY.md is not present; a public privacy-policy URL is still required before Play production release.")
else:
    privacy_text = privacy.read_text().lower()
    for marker in ("local-first", "in-app purchase", "google ml kit", "notifications", "share"):
        if marker not in privacy_text:
            warnings.append(f"PRIVACY_POLICY.md should explicitly document: {marker}.")

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

# Production signing configuration must be explicit and never use a hard-coded keystore.
workflow = ROOT / ".github/workflows/nova-android-ci.yml"
if workflow.exists():
    wf = workflow.read_text()
    if "production_release" not in wf: errors.append("CI is missing the production_release signing gate.")
    if "ORAH_UPLOAD_KEYSTORE_B64" not in wf: errors.append("CI is missing the upload keystore secret.")
    if "Configure production signing in Gradle" not in wf: errors.append("CI is missing Gradle release-signing configuration.")
    if "tool/configure_release_signing.py" not in wf: errors.append("CI is missing the release-signing configurator.")
signing_tool = ROOT / 'tool/configure_release_signing.py'
if not signing_tool.exists(): errors.append('Missing release signing configurator.')

# Production billing boundary documentation.
const_billing_doc = ROOT / "PLAY_BILLING_VERIFICATION.md"
if not const_billing_doc.exists():
    errors.append("Missing production billing verification architecture document.")
else:
    billing = const_billing_doc.read_text().lower()
    for marker in ("purchase token", "google play developer api", "real-time developer notifications"):
        if marker not in billing: errors.append(f"Billing verification document is missing required marker: {marker}.")
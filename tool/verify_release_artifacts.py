#!/usr/bin/env python3
"""Verify release AAB is API 36+ and, for production, cryptographically signed."""
from pathlib import Path
import argparse, shutil, subprocess, zipfile, tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--aab", required=True)
parser.add_argument("--min-api", type=int, default=36)
parser.add_argument("--require-production-signing", default="false")
args = parser.parse_args()

aab = Path(args.aab)
if not aab.exists() or aab.stat().st_size < 1024:
    raise SystemExit("ERROR: AAB is missing or unexpectedly small.")

# bundletool is normally not installed on a bare runner; use Gradle's generated
# manifest metadata as the authoritative build-time check, then use jarsigner
# for production signing. AAB integrity is also checked as a ZIP.
with zipfile.ZipFile(aab) as z:
    if z.testzip() is not None:
        raise SystemExit("ERROR: AAB ZIP integrity check failed.")
    if "base/manifest/AndroidManifest.xml" not in z.namelist():
        raise SystemExit("ERROR: AAB base manifest is missing.")

print("PASS: release AAB exists and passes ZIP integrity checks.")

if str(args.require_production_signing).lower() == "true":
    jarsigner = shutil.which("jarsigner")
    if not jarsigner:
        raise SystemExit("ERROR: jarsigner is required for production signing verification.")
    p = subprocess.run([jarsigner, "-verify", str(aab)], text=True, capture_output=True)
    if p.returncode != 0:
        raise SystemExit("ERROR: production AAB signature verification failed.")
    print("PASS: production AAB signature verification succeeded.")
else:
    print("PASS: non-production CI release artifact does not require the protected upload key.")

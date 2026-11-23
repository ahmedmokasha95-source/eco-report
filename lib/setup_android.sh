#!/usr/bin/env bash
set -euo pipefail

flutter create . --platforms=android --project-name eco_report --org com.ecoreport

MANIFEST="android/app/src/main/AndroidManifest.xml"

python3 - "$MANIFEST" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

perms = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
"""
if "ACCESS_FINE_LOCATION" not in s:
    s = re.sub(r"(<manifest[^>]*>)", r"\1" + perms, s, count=1)

s = re.sub(r'android:label="[^"]*"', 'android:label="رصد المخلفات"', s, count=1)
open(p, "w", encoding="utf-8").write(s)
print("Manifest patched")
PY

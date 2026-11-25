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

s = re.sub(r'android:label="[^"]*"', 'android:label="بلّاغ"', s, count=1)
open(p, "w", encoding="utf-8").write(s)
print("Manifest patched")
PY

# ── دعم البصمة (local_auth) والتخزين الآمن (flutter_secure_storage) ──
python3 - "$MANIFEST" <<'PY'
import sys, glob, re
manifest = sys.argv[1]
s = open(manifest, encoding="utf-8").read()
if "USE_BIOMETRIC" not in s:
    s = re.sub(r"(<manifest[^>]*>)",
               r'\1\n    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>',
               s, count=1)
open(manifest, "w", encoding="utf-8").write(s)

# local_auth محتاج FragmentActivity
for p in glob.glob("android/app/src/main/**/MainActivity.*", recursive=True):
    t = open(p, encoding="utf-8").read()
    t = t.replace("import io.flutter.embedding.android.FlutterActivity",
                  "import io.flutter.embedding.android.FlutterFragmentActivity")
    t = t.replace(": FlutterActivity()", ": FlutterFragmentActivity()")
    open(p, "w", encoding="utf-8").write(t)

# ثيم AppCompat عشان نافذة البصمة تشتغل على كل الإصدارات
for p in glob.glob("android/app/src/main/res/values*/styles.xml"):
    t = open(p, encoding="utf-8").read()
    t = t.replace("@android:style/Theme.Light.NoTitleBar", "@style/Theme.AppCompat.Light.NoActionBar")
    t = t.replace("@android:style/Theme.Black.NoTitleBar", "@style/Theme.AppCompat.NoActionBar")
    open(p, "w", encoding="utf-8").write(t)

# flutter_secure_storage محتاج minSdk 23 على الأقل
for p in glob.glob("android/app/build.gradle*"):
    t = open(p, encoding="utf-8").read()
    t = t.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")
    t = t.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 23")
    open(p, "w", encoding="utf-8").write(t)
print("Biometric Android settings patched")
PY

# ── أيقونة التطبيق (ورقة شجر + إشارة) ──
python3 - <<'PY2'
import os, shutil
res = "android/app/src/main/res"
for d in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    os.makedirs(f"{res}/mipmap-{d}", exist_ok=True)
    for n in ["ic_launcher.png", "ic_launcher_foreground.png"]:
        shutil.copy(f"icon_assets/{d}/{n}", f"{res}/mipmap-{d}/{n}")
os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n')
os.makedirs(f"{res}/values", exist_ok=True)
open(f"{res}/values/ic_launcher_background.xml", "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="ic_launcher_background">#0B1F1A</color>\n</resources>\n')
print("Launcher icon installed")
PY2

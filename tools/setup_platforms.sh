#!/usr/bin/env bash
# One-time setup: generates the Android and iOS folders, app icons, and the
# Android settings the game needs. Run from the project root:  bash tools/setup_platforms.sh
set -e

flutter create --platforms=android,ios --project-name shackleton_station --org org.spaceapps .
flutter pub get
dart run flutter_launcher_icons

MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ] && ! grep -q 'android.intent.action.VIEW' "$MANIFEST"; then
  # lets the Mission Data links open in the browser, and the read-aloud
  # voice find the phone's speech engine, on Android 11+; portrait only
  python3 - "$MANIFEST" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
q = '''    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>
'''
if '<queries>' in s:
    s = s.replace('<queries>', q.strip().replace('</queries>', '').rstrip() + '\n', 1)
else:
    s = s.replace('</manifest>', q + '</manifest>')
s = s.replace('android:label="shackleton_station"', 'android:label="Open Bounds"')
# release builds need this for sign-in, cloud progress, co-op and NASA data
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
if 'android:screenOrientation' not in s:
    s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:screenOrientation="portrait"', 1)
open(p, 'w').write(s)
EOF
fi

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then
  sed -i.bak 's#<string>shackleton_station</string>#<string>Open Bounds</string>#' "$PLIST" && rm -f "$PLIST.bak"
  # portrait only on iPhone
  python3 - "$PLIST" <<'PLISTEOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'(<key>UISupportedInterfaceOrientations</key>\s*<array>).*?(</array>)',
           r'\1\n\t\t<string>UIInterfaceOrientationPortrait</string>\n\t\2', s, count=1, flags=re.S)
open(p, 'w').write(s)
PLISTEOF
fi

echo "Done. Connect a phone and run:"
echo "  flutter run --release                                        # offline: guest play, sample teacher class"
echo "  flutter run --release --dart-define-from-file=env/dev.json   # with Clerk + Supabase (see README)"

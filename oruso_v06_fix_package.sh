#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path(".github/workflows/build-apk.yml")
text = path.read_text(encoding="utf-8")

needle = '          app.write_text(text)\n          PY\n'

replacement = '''          text = text.replace(
              'applicationId = "com.oruso.oruso"',
              'applicationId = "com.oruso.app"',
          )
          app.write_text(text)
          PY
'''

if 'applicationId = "com.oruso.app"' not in text:
    if needle not in text:
        raise SystemExit("Firebase設定部分が見つかりませんでした。")
    text = text.replace(needle, replacement, 1)

path.write_text(text, encoding="utf-8")
PY

git add .github/workflows/build-apk.yml oruso_v06_fix_package.sh
git commit -m "Fix Android package name for Firebase" || true
git push origin main

echo
echo "ORUSO Firebase package fix complete."

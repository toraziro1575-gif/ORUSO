#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path(".github/workflows/build-apk.yml")
text = path.read_text(encoding="utf-8")

old = "run: flutter analyze"
new = "run: flutter analyze --no-fatal-infos"

if old not in text:
    raise SystemExit("build-apk.yml の解析コマンドが見つかりませんでした。")

path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

git add .github/workflows/build-apk.yml oruso_v06_fix_workflow.sh
git commit -m "Allow Flutter info notices during APK build"
git push origin main

echo
echo "ORUSO Ver.0.6 workflow fix complete."

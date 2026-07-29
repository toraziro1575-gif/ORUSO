#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path("lib/main.dart")
text = path.read_text(encoding="utf-8")

replacements = {
    "if (value != null) setState(() => mealType = value);": """if (value != null) {
              setState(() => mealType = value);
            }""",
    "if (food.text.trim().isEmpty) return;": """if (food.text.trim().isEmpty) {
      return;
    }""",
}

missing = []
for old, new in replacements.items():
    if old not in text:
        missing.append(old)
    text = text.replace(old, new)

if missing:
    print("注意: 一部の対象行が見つかりませんでした:")
    for item in missing:
        print(item)

path.write_text(text, encoding="utf-8")
PY

git add lib/main.dart oruso_v06_fix_analyze.sh
git commit -m "Fix Flutter analyzer block warnings" || true
git push origin main

echo
echo "ORUSO Ver.0.6 analyzer fix complete."

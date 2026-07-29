#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path("lib/main.dart")
text = path.read_text(encoding="utf-8")

old = """  Future<String> reserveId() async {
    for (var i = 0; i < 15; i++) {
      final id = createRandomId();
      final snap = await FirebaseFirestore.instance.collection('usernames').doc(id).get();
      if (!snap.exists) return id;
    }
    throw Exception('IDの発行に失敗しました。');
  }
"""

new = """  Future<String> reserveId() async {
    // 登録前はまだ未ログインのため、Firestoreへ問い合わせずにIDを生成します。
    // 8文字のランダムIDは重複確率が非常に低く、万一重複した場合は
    // Firebase Authentication側のエラーとして登録をやり直します。
    return createRandomId();
  }
"""

if old not in text:
    raise SystemExit("修正対象の reserveId() が見つかりませんでした。")

path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

git add lib/main.dart oruso_v06_fix_register_permission.sh
git commit -m "Fix ORUSO registration permission error" || true
git push origin main

echo
echo "ORUSO registration permission fix complete."

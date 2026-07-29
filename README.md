# ORUSO Ver.0.6

公式アイコン、ORUSO IDログイン、クラウド保存、プロフィール、フレンド機能を追加した初期版です。

## 追加内容
- スマホのホーム画面アイコンをORUSOロゴへ変更
- アプリ左上・登録画面・マイページにもORUSOロゴを表示
- 本物のメールアドレスを使わないランダムORUSO ID
- ORUSO ID＋自分で設定したパスワードでログイン
- 筋トレ・食事・体重のクラウド保存
- ニックネーム・自己紹介・公開範囲
- ID検索・フレンド申請・承認
- Firestore Security Rules

## 重要
1. Firebase Authenticationの「メール／パスワード」を有効にしておく
2. リポジトリ直下にgoogle-services.jsonを置く
3. firestore.rulesの内容をFirebaseコンソールのFirestore「ルール」へ貼り付けて公開する
4. パスワード忘れの復旧機能はまだありません

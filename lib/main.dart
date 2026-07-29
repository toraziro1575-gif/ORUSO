import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const OrusoApp());
}

class OrusoApp extends StatelessWidget {
  const OrusoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ORUSO',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8ED1B2),
        scaffoldBackgroundColor: const Color(0xFF101414),
        cardTheme: const CardThemeData(color: Color(0xFF1A2221)),
      ),
      home: const AuthGate(),
    );
  }
}

String normalizeId(String value) => value.trim().toUpperCase();
String internalEmail(String id) => '${id.toLowerCase()}@users.oruso.app';

String createRandomId() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  final code = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  return 'ORUSO-$code';
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == null
            ? const LoginPage()
            : MainPage(user: snapshot.data!);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  bool registerMode = false;
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String> reserveId() async {
    for (var i = 0; i < 15; i++) {
      final id = createRandomId();
      final snap = await FirebaseFirestore.instance.collection('usernames').doc(id).get();
      if (!snap.exists) return id;
    }
    throw Exception('IDの発行に失敗しました。');
  }

  Future<void> register() async {
    if (passwordController.text.length < 8) {
      message('パスワードは8文字以上にしてください。');
      return;
    }

    setState(() => busy = true);
    UserCredential? credential;
    try {
      final id = await reserveId();
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: internalEmail(id),
        password: passwordController.text,
      );

      final uid = credential.user!.uid;
      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('users').doc(uid), {
        'uid': uid,
        'userId': id,
        'nickname': 'ORUSOユーザー',
        'bio': '',
        'visibility': 'private',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(FirebaseFirestore.instance.collection('usernames').doc(id), {
        'uid': uid,
        'userId': id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('あなたのORUSO ID'),
          content: SelectableText(
            '$id\n\nこのIDと設定したパスワードでログインします。\n'
            '本物のメールアドレスは登録しません。\n'
            '現段階ではパスワードを忘れると復旧できないため、必ず保存してください。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('保存しました'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (credential?.user != null) {
        await credential!.user!.delete().catchError((_) {});
      }
      message('登録に失敗しました：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() async {
    final id = normalizeId(idController.text);
    if (!id.startsWith('ORUSO-') || passwordController.text.isEmpty) {
      message('ORUSO IDとパスワードを入力してください。');
      return;
    }

    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: internalEmail(id),
        password: passwordController.text,
      );
    } catch (_) {
      message('IDまたはパスワードが違います。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 22),
            Image.asset('assets/oruso_logo.png', height: 170),
            const SizedBox(height: 12),
            Text(
              'ORUSO',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Text(
              '記録で強くなる、つながりで続く。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('ログイン')),
                ButtonSegment(value: true, label: Text('新規登録')),
              ],
              selected: {registerMode},
              onSelectionChanged: busy
                  ? null
                  : (values) => setState(() => registerMode = values.first),
            ),
            const SizedBox(height: 18),
            if (!registerMode)
              TextField(
                controller: idController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'ORUSO ID',
                  hintText: 'ORUSO-XXXXXXXX',
                  border: OutlineInputBorder(),
                ),
              )
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '新規登録時にランダムなORUSO IDを発行します。'
                    '\nメールアドレス・電話番号・住所は入力しません。',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: registerMode ? '設定するパスワード（8文字以上）' : 'パスワード',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : (registerMode ? register : login),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(registerMode ? Icons.person_add : Icons.login),
              label: Text(registerMode ? 'IDを発行して登録' : 'ログイン'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.user});
  final User user;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CloudRecordsPage(uid: widget.user.uid),
      FriendsPage(user: widget.user),
      ProfilePage(user: widget.user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/oruso_logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text('ORUSO', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'クラウド記録',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'フレンド',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'マイページ',
          ),
        ],
      ),
    );
  }
}

class CloudRecordsPage extends StatefulWidget {
  const CloudRecordsPage({super.key, required this.uid});
  final String uid;

  @override
  State<CloudRecordsPage> createState() => _CloudRecordsPageState();
}

class _CloudRecordsPageState extends State<CloudRecordsPage> {
  final workoutController = TextEditingController();
  final mealController = TextEditingController();
  final weightController = TextEditingController();

  CollectionReference<Map<String, dynamic>> records(String type) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection(type);

  @override
  void dispose() {
    workoutController.dispose();
    mealController.dispose();
    weightController.dispose();
    super.dispose();
  }

  Future<void> addRecord(String type, String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    await records(type).add({
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Widget recordSection({
    required String title,
    required String type,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () async {
                    await addRecord(type, controller.text);
                    controller.clear();
                  },
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: records(type)
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const Text('まだ記録がありません');
                return Column(
                  children: docs
                      .map(
                        (doc) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon),
                          title: Text(doc.data()['text'] as String? ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'クラウド保存',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        const Text('この画面の記録はFirebaseへ保存されます。'),
        const SizedBox(height: 16),
        recordSection(
          title: '筋トレ',
          type: 'workouts',
          controller: workoutController,
          hint: '例：スクワット 40kg 10回×3',
          icon: Icons.fitness_center,
        ),
        recordSection(
          title: '食事',
          type: 'meals',
          controller: mealController,
          hint: '例：朝食 鶏むね肉・ごはん',
          icon: Icons.restaurant,
        ),
        recordSection(
          title: '体重',
          type: 'weights',
          controller: weightController,
          hint: '例：73.0kg',
          icon: Icons.monitor_weight,
        ),
      ],
    );
  }
}

String friendshipId(String a, String b) {
  final values = [a, b]..sort();
  return '${values[0]}_${values[1]}';
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.user});
  final User user;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final idController = TextEditingController();
  Map<String, dynamic>? foundUser;

  @override
  void dispose() {
    idController.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> searchUser() async {
    final id = normalizeId(idController.text);
    final username =
        await FirebaseFirestore.instance.collection('usernames').doc(id).get();
    if (!username.exists) {
      message('ユーザーが見つかりません。');
      setState(() => foundUser = null);
      return;
    }

    final uid = username.data()!['uid'] as String;
    final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() => foundUser = user.data());
  }

  Future<void> sendRequest() async {
    final receiverUid = foundUser?['uid'] as String?;
    if (receiverUid == null || receiverUid == widget.user.uid) return;

    final requestId = '${widget.user.uid}_$receiverUid';
    await FirebaseFirestore.instance.collection('friendRequests').doc(requestId).set({
      'senderUid': widget.user.uid,
      'receiverUid': receiverUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    message('フレンド申請を送りました。');
  }

  Future<void> accept(
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final sender = request['senderUid'] as String;
    final receiver = request['receiverUid'] as String;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('friendRequests').doc(requestId),
      {'status': 'accepted'},
    );
    batch.set(
      FirebaseFirestore.instance
          .collection('friendships')
          .doc(friendshipId(sender, receiver)),
      {
        'members': [sender, receiver],
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final requestStream = FirebaseFirestore.instance
        .collection('friendRequests')
        .where('receiverUid', isEqualTo: widget.user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final friendStream = FirebaseFirestore.instance
        .collection('friendships')
        .where('members', arrayContains: widget.user.uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'フレンド',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: idController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'ORUSO IDで検索',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: searchUser,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        if (foundUser != null) ...[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(foundUser!['nickname'] as String? ?? 'ORUSOユーザー'),
              subtitle: Text(foundUser!['userId'] as String? ?? ''),
              trailing: FilledButton(
                onPressed: sendRequest,
                child: const Text('申請'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const Text('届いた申請', style: TextStyle(fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: requestStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('申請はありません'),
            );
            return Column(
              children: docs
                  .map(
                    (doc) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('フレンド申請'),
                        trailing: FilledButton(
                          onPressed: () => accept(doc.id, doc.data()),
                          child: const Text('承認'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text('フレンド一覧', style: TextStyle(fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: friendStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('フレンドはまだいません'),
            );
            return Column(
              children: docs.map((doc) {
                final members = List<String>.from(doc.data()['members'] as List);
                final other = members.firstWhere((uid) => uid != widget.user.uid);
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('users').doc(other).get(),
                  builder: (context, snap) {
                    final data = snap.data?.data();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.people),
                        title: Text(data?['nickname'] as String? ?? '読み込み中'),
                        subtitle: Text(data?['userId'] as String? ?? ''),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});
  final User user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nicknameController = TextEditingController();
  final bioController = TextEditingController();
  String visibility = 'private';
  String userId = '';
  bool loaded = false;

  DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final snap = await ref.get();
    final data = snap.data() ?? {};
    nicknameController.text = data['nickname'] as String? ?? '';
    bioController.text = data['bio'] as String? ?? '';
    visibility = data['visibility'] as String? ?? 'private';
    userId = data['userId'] as String? ?? '';
    if (mounted) setState(() => loaded = true);
  }

  Future<void> save() async {
    await ref.update({
      'nickname': nicknameController.text.trim(),
      'bio': bioController.text.trim(),
      'visibility': visibility,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを保存しました。')),
      );
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipOval(
            child: Image.asset(
              'assets/oruso_logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SelectableText(
          userId,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            labelText: 'ニックネーム',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bioController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '自己紹介',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: visibility,
          decoration: const InputDecoration(
            labelText: '公開範囲',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'private', child: Text('自分だけ')),
            DropdownMenuItem(value: 'friends', child: Text('フレンドのみ')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => visibility = value);
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: FirebaseAuth.instance.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('ログアウト'),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security),
            title: Text('通信の安全対策'),
            subtitle: Text(
              'Firebase AuthenticationとFirestore Security Rulesでアクセスを制限します。',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ORUSO Ver.0.6'),
            subtitle: Text('公式アイコン・IDログイン・クラウド・フレンド'),
          ),
        ),
      ],
    );
  }
}

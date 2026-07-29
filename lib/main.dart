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

DateTime dateFrom(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.now();
}

String ymd(DateTime d) => '${d.year}/${d.month}/${d.day}';
String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
            : MainShell(user: snapshot.data!);
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

  Future<void> register() async {
    if (passwordController.text.length < 8) {
      message('パスワードは8文字以上にしてください。');
      return;
    }

    setState(() => busy = true);
    UserCredential? credential;
    try {
      final id = createRandomId();
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
            '$id\n\nこのIDとパスワードでログインします。\n'
            'メールアドレス・電話番号・住所は登録しません。\n'
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
            const SizedBox(height: 20),
            Image.asset('assets/oruso_logo.png', height: 165),
            const SizedBox(height: 10),
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
                    '新規登録時にランダムなORUSO IDを発行します。\n'
                    'メールアドレス・電話番号・住所は入力しません。',
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

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.user});
  final User user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(uid: widget.user.uid),
      WorkoutPage(uid: widget.user.uid),
      MealPage(uid: widget.user.uid),
      CalendarPage(uid: widget.user.uid),
      WeightPage(uid: widget.user.uid),
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
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: '筋トレ'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: '食事'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'カレンダー'),
          NavigationDestination(icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: '体重'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'フレンド'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}

CollectionReference<Map<String, dynamic>> records(String uid, String type) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection(type);

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: records(uid, 'workouts').snapshots(),
      builder: (context, workoutSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: records(uid, 'meals').snapshots(),
          builder: (context, mealSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: records(uid, 'weights')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, weightSnap) {
                final workouts = workoutSnap.data?.docs ?? [];
                final meals = mealSnap.data?.docs ?? [];
                final weights = weightSnap.data?.docs ?? [];
                final latestWeight = weights.isEmpty
                    ? '未記録'
                    : '${(weights.first.data()['weight'] as num).toStringAsFixed(1)} kg';
                final today = DateTime.now();
                final todayWorkouts = workouts.where((d) {
                  final dt = dateFrom(d.data()['createdAt']);
                  return dt.year == today.year &&
                      dt.month == today.month &&
                      dt.day == today.day;
                }).toList();
                final todayMeals = meals.where((d) {
                  final dt = dateFrom(d.data()['createdAt']);
                  return dt.year == today.year &&
                      dt.month == today.month &&
                      dt.day == today.day;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '今日も一歩、強くなる。',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text('記録で強くなる、つながりで続く。'),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: StatCard(icon: Icons.fitness_center, value: '${workouts.length} 回', label: '筋トレ記録')),
                        const SizedBox(width: 10),
                        Expanded(child: StatCard(icon: Icons.monitor_weight, value: latestWeight, label: '最新体重')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: StatCard(icon: Icons.restaurant, value: '${todayMeals.length} 件', label: '今日の食事')),
                        const SizedBox(width: 10),
                        Expanded(child: StatCard(icon: Icons.local_fire_department, value: '${todayWorkouts.isEmpty ? 0 : 1} 日', label: '今日の達成')),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('今日のメニュー'),
                    if (todayWorkouts.isEmpty)
                      const EmptyCard(
                        icon: Icons.add_circle_outline,
                        title: 'まだ記録がありません',
                        subtitle: '筋トレタブから今日のトレーニングを追加できます。',
                      )
                    else
                      ...todayWorkouts.map((d) {
                        final x = d.data();
                        return RecordTile(
                          icon: Icons.fitness_center,
                          title: x['exercise'] as String? ?? '',
                          subtitle: '${x['weight']} kg × ${x['reps']}回 × ${x['sets']}セット',
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.uid});
  final String uid;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final exercise = TextEditingController();
  final weight = TextEditingController();
  final reps = TextEditingController();
  final sets = TextEditingController();
  final duration = TextEditingController();
  final memo = TextEditingController();

  @override
  void dispose() {
    exercise.dispose();
    weight.dispose();
    reps.dispose();
    sets.dispose();
    duration.dispose();
    memo.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final w = double.tryParse(weight.text);
    final r = int.tryParse(reps.text);
    final s = int.tryParse(sets.text);
    if (exercise.text.trim().isEmpty || w == null || r == null || s == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目・重量・回数・セット数を入力してください。')),
      );
      return;
    }

    final previous = await records(widget.uid, 'workouts')
        .where('exercise', isEqualTo: exercise.text.trim())
        .get();
    final oldPr = previous.docs.isEmpty
        ? null
        : previous.docs
            .map((d) => (d.data()['weight'] as num).toDouble())
            .reduce(max);

    await records(widget.uid, 'workouts').add({
      'exercise': exercise.text.trim(),
      'weight': w,
      'reps': r,
      'sets': s,
      'durationMinutes': int.tryParse(duration.text) ?? 0,
      'memo': memo.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (oldPr == null || w > oldPr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自己ベスト更新！ ${w.toStringAsFixed(1)} kg')),
        );
      }
    }
    weight.clear();
    reps.clear();
    sets.clear();
    duration.clear();
    memo.clear();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: records(widget.uid, 'workouts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('筋トレを記録'),
            TextField(
              controller: exercise,
              decoration: const InputDecoration(labelText: '種目', hintText: '例：ベンチプレス', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '重量（kg）', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '回数', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'セット数', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '時間（分）', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: memo, maxLines: 2, decoration: const InputDecoration(labelText: 'メモ（任意）', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('記録を追加')),
            const SizedBox(height: 22),
            const SectionTitle('記録一覧'),
            if (docs.isEmpty)
              const EmptyCard(icon: Icons.fitness_center, title: '記録はありません', subtitle: '最初のトレーニングを追加しましょう。')
            else
              ...docs.map((d) {
                final x = d.data();
                final dt = dateFrom(x['createdAt']);
                return RecordTile(
                  icon: Icons.fitness_center,
                  title: x['exercise'] as String? ?? '',
                  subtitle: '${x['weight']} kg × ${x['reps']}回 × ${x['sets']}セット\n${ymd(dt)} ${hm(dt)}',
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: d.reference.delete),
                );
              }),
          ],
        );
      },
    );
  }
}

class MealPage extends StatefulWidget {
  const MealPage({super.key, required this.uid});
  final String uid;

  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  final food = TextEditingController();
  final memo = TextEditingController();
  String type = '朝食';

  @override
  void dispose() {
    food.dispose();
    memo.dispose();
    super.dispose();
  }

  Future<void> add() async {
    if (food.text.trim().isEmpty) {
      return;
    }
    await records(widget.uid, 'meals').add({
      'mealType': type,
      'food': food.text.trim(),
      'memo': memo.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    food.clear();
    memo.clear();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: records(widget.uid, 'meals').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('食事を記録'),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: '食事の種類', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '朝食', child: Text('朝食')),
                DropdownMenuItem(value: '昼食', child: Text('昼食')),
                DropdownMenuItem(value: '夕食', child: Text('夕食')),
                DropdownMenuItem(value: '間食', child: Text('間食')),
                DropdownMenuItem(value: 'その他', child: Text('その他')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => type = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: food, decoration: const InputDecoration(labelText: '食べたもの', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: memo, maxLines: 2, decoration: const InputDecoration(labelText: 'メモ（任意）', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('食事を追加')),
            const SizedBox(height: 22),
            const SectionTitle('食事記録'),
            if (docs.isEmpty)
              const EmptyCard(icon: Icons.restaurant, title: '記録はありません', subtitle: '最初の食事を追加しましょう。')
            else
              ...docs.map((d) {
                final x = d.data();
                final dt = dateFrom(x['createdAt']);
                return RecordTile(
                  icon: Icons.restaurant,
                  title: '${x['mealType']}　${x['food']}',
                  subtitle: '${ymd(dt)} ${hm(dt)}${(x['memo'] as String? ?? '').isEmpty ? '' : '\n${x['memo']}'}',
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: d.reference.delete),
                );
              }),
          ],
        );
      },
    );
  }
}

class WeightPage extends StatefulWidget {
  const WeightPage({super.key, required this.uid});
  final String uid;

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final value = double.tryParse(controller.text);
    if (value == null) {
      return;
    }
    await records(widget.uid, 'weights').add({
      'weight': value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: records(widget.uid, 'weights').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('体重を記録'),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '体重（kg）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('体重を追加')),
            const SizedBox(height: 22),
            ...docs.map((d) {
              final x = d.data();
              final dt = dateFrom(x['createdAt']);
              return RecordTile(
                icon: Icons.monitor_weight,
                title: '${(x['weight'] as num).toStringAsFixed(1)} kg',
                subtitle: '${ymd(dt)} ${hm(dt)}',
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: d.reference.delete),
              );
            }),
          ],
        );
      },
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.uid});
  final String uid;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: records(widget.uid, 'workouts').snapshots(),
      builder: (context, workoutSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: records(widget.uid, 'meals').snapshots(),
          builder: (context, mealSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: records(widget.uid, 'weights').snapshots(),
              builder: (context, weightSnap) {
                final workouts = workoutSnap.data?.docs ?? [];
                final meals = mealSnap.data?.docs ?? [];
                final weights = weightSnap.data?.docs ?? [];
                final now = DateTime.now();
                final days = DateUtils.getDaysInMonth(now.year, now.month);
                final leading = DateTime(now.year, now.month, 1).weekday % 7;
                const weekdays = ['日', '月', '火', '水', '木', '金', '土'];

                final selectedWorkouts = workouts.where((d) => sameDay(dateFrom(d.data()['createdAt']), selected)).toList();
                final selectedMeals = meals.where((d) => sameDay(dateFrom(d.data()['createdAt']), selected)).toList();
                final selectedWeights = weights.where((d) => sameDay(dateFrom(d.data()['createdAt']), selected)).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SectionTitle('${now.year}年 ${now.month}月'),
                    Row(
                      children: weekdays.map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold))))).toList(),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
                      itemCount: leading + days,
                      itemBuilder: (_, index) {
                        if (index < leading) {
                          return const SizedBox.shrink();
                        }
                        final day = index - leading + 1;
                        final date = DateTime(now.year, now.month, day);
                        final hasWorkout = workouts.any((d) => sameDay(dateFrom(d.data()['createdAt']), date));
                        final hasMeal = meals.any((d) => sameDay(dateFrom(d.data()['createdAt']), date));
                        final hasWeight = weights.any((d) => sameDay(dateFrom(d.data()['createdAt']), date));
                        return InkWell(
                          onTap: () => setState(() => selected = date),
                          child: Container(
                            decoration: BoxDecoration(
                              color: hasWorkout ? Theme.of(context).colorScheme.primaryContainer : const Color(0xFF1A2221),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sameDay(selected, date) ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$day'),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasWorkout) const Icon(Icons.fitness_center, size: 9),
                                    if (hasMeal) const Icon(Icons.restaurant, size: 9),
                                    if (hasWeight) const Icon(Icons.monitor_weight, size: 9),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    SectionTitle('${ymd(selected)} の記録'),
                    if (selectedWorkouts.isEmpty && selectedMeals.isEmpty && selectedWeights.isEmpty)
                      const EmptyCard(icon: Icons.event_note, title: 'この日の記録はありません', subtitle: '筋トレ・食事・体重を記録すると表示されます。'),
                    ...selectedWorkouts.map((d) {
                      final x = d.data();
                      return RecordTile(icon: Icons.fitness_center, title: x['exercise'] as String? ?? '', subtitle: '${x['weight']} kg × ${x['reps']}回 × ${x['sets']}セット');
                    }),
                    ...selectedMeals.map((d) {
                      final x = d.data();
                      return RecordTile(icon: Icons.restaurant, title: '${x['mealType']}　${x['food']}', subtitle: hm(dateFrom(x['createdAt'])));
                    }),
                    ...selectedWeights.map((d) {
                      final x = d.data();
                      return RecordTile(icon: Icons.monitor_weight, title: '${x['weight']} kg', subtitle: hm(dateFrom(x['createdAt'])));
                    }),
                  ],
                );
              },
            );
          },
        );
      },
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
    final username = await FirebaseFirestore.instance.collection('usernames').doc(id).get();
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
    if (receiverUid == null || receiverUid == widget.user.uid) {
      return;
    }
    final requestId = '${widget.user.uid}_$receiverUid';
    await FirebaseFirestore.instance.collection('friendRequests').doc(requestId).set({
      'senderUid': widget.user.uid,
      'receiverUid': receiverUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    message('フレンド申請を送りました。');
  }

  Future<void> accept(String requestId, Map<String, dynamic> request) async {
    final sender = request['senderUid'] as String;
    final receiver = request['receiverUid'] as String;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('friendRequests').doc(requestId),
      {'status': 'accepted'},
    );
    batch.set(
      FirebaseFirestore.instance.collection('friendships').doc(friendshipId(sender, receiver)),
      {'members': [sender, receiver], 'createdAt': FieldValue.serverTimestamp()},
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
        const SectionTitle('フレンド'),
        TextField(
          controller: idController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'ORUSO IDで検索',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(onPressed: searchUser, icon: const Icon(Icons.search)),
          ),
        ),
        if (foundUser != null) ...[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(foundUser!['nickname'] as String? ?? 'ORUSOユーザー'),
              subtitle: Text(foundUser!['userId'] as String? ?? ''),
              trailing: FilledButton(onPressed: sendRequest, child: const Text('申請')),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text('届いた申請', style: TextStyle(fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: requestStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('申請はありません'));
            }
            return Column(
              children: docs.map((d) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('フレンド申請'),
                  trailing: FilledButton(onPressed: () => accept(d.id, d.data()), child: const Text('承認')),
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('フレンド一覧', style: TextStyle(fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: friendStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('フレンドはまだいません'));
            }
            return Column(
              children: docs.map((d) {
                final members = List<String>.from(d.data()['members'] as List);
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
    if (mounted) {
      setState(() => loaded = true);
    }
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
    if (!loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipOval(
            child: Image.asset('assets/oruso_logo.png', width: 120, height: 120, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(userId, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        TextField(controller: nicknameController, decoration: const InputDecoration(labelText: 'ニックネーム', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: bioController, maxLines: 3, decoration: const InputDecoration(labelText: '自己紹介', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: visibility,
          decoration: const InputDecoration(labelText: '公開範囲', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'private', child: Text('自分だけ')),
            DropdownMenuItem(value: 'friends', child: Text('フレンドのみ')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => visibility = value);
            }
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('保存')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: FirebaseAuth.instance.signOut, icon: const Icon(Icons.logout), label: const Text('ログアウト')),
        const SizedBox(height: 14),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security),
            title: Text('通信と公開範囲'),
            subtitle: Text('Firebase AuthenticationとFirestore Security Rulesで保護します。'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ORUSO Ver.0.7'),
            subtitle: Text('旧機能とクラウド・フレンド機能を統合'),
          ),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.icon, required this.title, required this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}


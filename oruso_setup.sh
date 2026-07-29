#!/usr/bin/env bash
set -euo pipefail

mkdir -p lib .github/workflows

cat > pubspec.yaml <<'EOF'
name: oruso
description: ORUSO - Workout, Meal & Friends App
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
EOF

cat > analysis_options.yaml <<'EOF'
include: package:flutter_lints/flutter.yaml
EOF

cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';

void main() {
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
        colorSchemeSeed: const Color(0xFF8ED1B2),
        scaffoldBackgroundColor: const Color(0xFF101414),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          color: Color(0xFF1A2221),
          margin: EdgeInsets.zero,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final workouts = <WorkoutEntry>[];
  final weights = <WeightEntry>[];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(workouts: workouts, weights: weights),
      WorkoutPage(
        workouts: workouts,
        onAdded: (entry) => setState(() => workouts.add(entry)),
      ),
      CalendarPage(workouts: workouts),
      WeightPage(
        weights: weights,
        onAdded: (entry) => setState(() => weights.add(entry)),
      ),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFF8ED1B2),
              child: Text('🐱', style: TextStyle(fontSize: 19)),
            ),
            SizedBox(width: 10),
            Text('ORUSO', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: '筋トレ'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'カレンダー'),
          NavigationDestination(icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: '体重'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.workouts, required this.weights});

  final List<WorkoutEntry> workouts;
  final List<WeightEntry> weights;

  @override
  Widget build(BuildContext context) {
    final latestWeight = weights.isEmpty ? '未記録' : '${weights.last.weight.toStringAsFixed(1)} kg';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('今日も一歩、強くなる。', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('記録で強くなる、つながりで続く。', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: StatCard(title: '筋トレ記録', value: '${workouts.length} 回', icon: Icons.fitness_center)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: '最新体重', value: latestWeight, icon: Icons.monitor_weight)),
          ],
        ),
        const SizedBox(height: 12),
        const StatCard(title: '継続日数', value: '0 日', icon: Icons.local_fire_department),
        const SizedBox(height: 24),
        Text('今日のメニュー', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const EmptyCard(
          icon: Icons.add_circle_outline,
          title: 'まだ記録がありません',
          subtitle: '「筋トレ」タブから今日のトレーニングを追加できます。',
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(title),
          ],
        ),
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
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class WorkoutEntry {
  WorkoutEntry({required this.exercise, required this.weight, required this.reps, required this.sets, required this.createdAt});
  final String exercise;
  final double weight;
  final int reps;
  final int sets;
  final DateTime createdAt;
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.workouts, required this.onAdded});
  final List<WorkoutEntry> workouts;
  final ValueChanged<WorkoutEntry> onAdded;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final exercise = TextEditingController();
  final weight = TextEditingController();
  final reps = TextEditingController();
  final sets = TextEditingController();

  void addWorkout() {
    final w = double.tryParse(weight.text);
    final r = int.tryParse(reps.text);
    final s = int.tryParse(sets.text);
    if (exercise.text.trim().isEmpty || w == null || r == null || s == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('種目・重量・回数・セット数を入力してください。')));
      return;
    }
    widget.onAdded(WorkoutEntry(
      exercise: exercise.text.trim(),
      weight: w,
      reps: r,
      sets: s,
      createdAt: DateTime.now(),
    ));
    exercise.clear();
    weight.clear();
    reps.clear();
    sets.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    exercise.dispose();
    weight.dispose();
    reps.dispose();
    sets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('筋トレを記録', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        TextField(controller: exercise, decoration: const InputDecoration(labelText: '種目', hintText: '例：ベンチプレス', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '重量（kg）', border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '回数', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'セット数', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: addWorkout, icon: const Icon(Icons.add), label: const Text('記録を追加')),
        const SizedBox(height: 24),
        Text('記録一覧', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (widget.workouts.isEmpty)
          const EmptyCard(icon: Icons.fitness_center, title: '筋トレ記録はまだありません', subtitle: '最初のトレーニングを登録しましょう。')
        else
          ...widget.workouts.reversed.map((e) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
              title: Text(e.exercise, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${e.weight.toStringAsFixed(1)} kg × ${e.reps}回 × ${e.sets}セット'),
            ),
          )),
      ],
    );
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.workouts});
  final List<WorkoutEntry> workouts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = DateUtils.getDaysInMonth(now.year, now.month);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${now.year}年 ${now.month}月', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 7, crossAxisSpacing: 7),
          itemCount: days,
          itemBuilder: (_, index) {
            final day = index + 1;
            final trained = workouts.any((w) => w.createdAt.year == now.year && w.createdAt.month == now.month && w.createdAt.day == day);
            return Container(
              decoration: BoxDecoration(
                color: trained ? Theme.of(context).colorScheme.primaryContainer : const Color(0xFF1A2221),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text('$day', style: TextStyle(fontWeight: trained ? FontWeight.bold : FontWeight.normal))),
            );
          },
        ),
        const SizedBox(height: 18),
        Text('今月の筋トレ：${workouts.where((w) => w.createdAt.year == now.year && w.createdAt.month == now.month).length}回'),
      ],
    );
  }
}

class WeightEntry {
  WeightEntry({required this.weight, required this.createdAt});
  final double weight;
  final DateTime createdAt;
}

class WeightPage extends StatefulWidget {
  const WeightPage({super.key, required this.weights, required this.onAdded});
  final List<WeightEntry> weights;
  final ValueChanged<WeightEntry> onAdded;

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  final controller = TextEditingController();

  void addWeight() {
    final value = double.tryParse(controller.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('体重を数字で入力してください。')));
      return;
    }
    widget.onAdded(WeightEntry(weight: value, createdAt: DateTime.now()));
    controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('体重を記録', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '体重（kg）', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: addWeight, icon: const Icon(Icons.add), label: const Text('体重を追加')),
        const SizedBox(height: 24),
        if (widget.weights.isEmpty)
          const EmptyCard(icon: Icons.monitor_weight, title: '体重記録はまだありません', subtitle: '今日の体重を登録しましょう。')
        else
          ...widget.weights.reversed.map((e) => Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_weight),
              title: Text('${e.weight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${e.createdAt.year}/${e.createdAt.month}/${e.createdAt.day}'),
            ),
          )),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('設定', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.dark_mode), title: Text('ダークモード'), trailing: Switch(value: true, onChanged: null))),
        const SizedBox(height: 8),
        const Card(child: ListTile(leading: Icon(Icons.backup), title: Text('バックアップ'), subtitle: Text('今後のバージョンで追加予定'))),
        const SizedBox(height: 8),
        const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('ORUSO Ver.0.1'), subtitle: Text('端末内の一時記録版'))),
      ],
    );
  }
}
EOF

cat > .github/workflows/build-apk.yml <<'EOF'
name: Build ORUSO APK

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-android:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Create Android platform files
        run: flutter create --platforms=android --org com.oruso.app .

      - name: Get dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Build release APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: ORUSO-Android-APK
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 30
EOF

cat > README.md <<'EOF'
# ORUSO Ver.0.1

筋トレ・カレンダー・体重記録を備えた初期動作版です。

## 現在の機能
- ホーム
- 筋トレ記録（種目・重量・回数・セット）
- 当月カレンダー
- 体重記録
- 設定
- GitHub ActionsによるAPK自動作成

## 注意
Ver.0.1では記録はアプリ終了後に保存されません。
永続保存・食事・友達・ログインは次の段階で追加します。

## APK
GitHubの「Actions」→「Build ORUSO APK」→完了した実行→
「Artifacts」の `ORUSO-Android-APK` から取得します。
EOF

git add pubspec.yaml analysis_options.yaml lib/main.dart .github/workflows/build-apk.yml README.md oruso_setup.sh
git commit -m "Add ORUSO Ver.0.1 Flutter app and APK workflow" || true
git push origin main

echo
echo "ORUSO setup complete. GitHub Actions will now build the APK."

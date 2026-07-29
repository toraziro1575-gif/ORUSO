#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

main_path = Path("lib/main.dart")
text = main_path.read_text(encoding="utf-8")

text = text.replace(
    "CalendarPage(workouts: workouts),",
    "CalendarPage(workouts: workouts, meals: meals, weights: weights),",
)

start = text.find("class CalendarPage extends")
end = text.find("class WeightPage extends StatefulWidget")

if start == -1 or end == -1 or end <= start:
    raise SystemExit("CalendarPageの置換位置が見つかりませんでした。")

new_calendar = r"""class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.workouts,
    required this.meals,
    required this.weights,
  });

  final List<WorkoutEntry> workouts;
  final List<MealEntry> meals;
  final List<WeightEntry> weights;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = dayOnly(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDay = DateTime(now.year, now.month, 1);
    final leadingBlankDays = firstDay.weekday % 7;
    final totalCells = leadingBlankDays + daysInMonth;

    final monthlyCount = widget.workouts
        .where(
          (w) =>
              w.createdAt.year == now.year &&
              w.createdAt.month == now.month,
        )
        .length;

    final selectedWorkouts = widget.workouts
        .where((e) => dayOnly(e.createdAt) == selectedDate)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final selectedMeals = widget.meals
        .where((e) => dayOnly(e.createdAt) == selectedDate)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final selectedWeights = widget.weights
        .where((e) => dayOnly(e.createdAt) == selectedDate)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    const weekdays = ['日', '月', '火', '水', '木', '金', '土'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${now.year}年 ${now.month}月',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Row(
          children: weekdays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
          ),
          itemCount: totalCells,
          itemBuilder: (_, index) {
            if (index < leadingBlankDays) {
              return const SizedBox.shrink();
            }

            final day = index - leadingBlankDays + 1;
            final date = DateTime(now.year, now.month, day);
            final trained = widget.workouts.any(
              (w) =>
                  w.createdAt.year == now.year &&
                  w.createdAt.month == now.month &&
                  w.createdAt.day == day,
            );
            final hasMeal = widget.meals.any(
              (m) =>
                  m.createdAt.year == now.year &&
                  m.createdAt.month == now.month &&
                  m.createdAt.day == day,
            );
            final hasWeight = widget.weights.any(
              (w) =>
                  w.createdAt.year == now.year &&
                  w.createdAt.month == now.month &&
                  w.createdAt.day == day,
            );

            final isToday = now.year == date.year &&
                now.month == date.month &&
                now.day == date.day;
            final isSelected = selectedDate == dayOnly(date);

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => selectedDate = dayOnly(date)),
              child: Container(
                decoration: BoxDecoration(
                  color: trained
                      ? Theme.of(context).colorScheme.primaryContainer
                      : const Color(0xFF1A2221),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : isToday
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.55)
                            : Colors.transparent,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: trained || isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (trained)
                          const Icon(Icons.fitness_center, size: 9),
                        if (hasMeal)
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(Icons.restaurant, size: 9),
                          ),
                        if (hasWeight)
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(Icons.monitor_weight, size: 9),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text('今月の筋トレ：$monthlyCount回'),
        const SizedBox(height: 24),
        Text(
          '${selectedDate.year}/${selectedDate.month}/${selectedDate.day} の記録',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (selectedWorkouts.isEmpty &&
            selectedMeals.isEmpty &&
            selectedWeights.isEmpty)
          const EmptyCard(
            icon: Icons.event_note,
            title: 'この日の記録はありません',
            subtitle: '筋トレ・食事・体重を記録するとここに表示されます。',
          ),
        if (selectedWorkouts.isNotEmpty) ...[
          Text(
            '筋トレ',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...selectedWorkouts.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(
                    e.exercise,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${e.weight.toStringAsFixed(1)} kg × ${e.reps}回 × ${e.sets}セット'
                    '${e.durationMinutes > 0 ? '\n${e.durationMinutes}分' : ''}'
                    '${e.memo.isNotEmpty ? '\n${e.memo}' : ''}',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (selectedMeals.isNotEmpty) ...[
          Text(
            '食事',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...selectedMeals.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.restaurant),
                  ),
                  title: Text(
                    '${e.mealType}　${e.food}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${timeText(e.createdAt)}'
                    '${e.memo.isNotEmpty ? '\n${e.memo}' : ''}',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (selectedWeights.isNotEmpty) ...[
          Text(
            '体重',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...selectedWeights.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.monitor_weight),
                  ),
                  title: Text(
                    '${e.weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(timeText(e.createdAt)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

"""
text = text[:start] + new_calendar + text[end:]

text = text.replace(
    "title: Text('ORUSO Ver.0.4'),",
    "title: Text('ORUSO Ver.0.5'),",
)
text = text.replace(
    "subtitle: Text('前回重量・メモ・時間・PR表示に対応'),",
    "subtitle: Text('曜日表示と日別記録表示に対応'),",
)

main_path.write_text(text, encoding="utf-8")

pubspec_path = Path("pubspec.yaml")
pubspec = pubspec_path.read_text(encoding="utf-8")
pubspec = pubspec.replace("version: 0.4.0+4", "version: 0.5.0+5")
pubspec_path.write_text(pubspec, encoding="utf-8")
PY

cat > README.md <<'EOF'
# ORUSO Ver.0.5

曜日表示と日別記録表示をまとめて追加したバージョンです。

## Ver.0.5の追加内容
- カレンダーに曜日（日〜土）を表示
- 月初の日付を正しい曜日位置に配置
- 今日の日付を枠線で強調
- 日付をタップして選択
- 選択日の筋トレ・食事・体重をまとめて表示
- 記録のある日に小さなアイコンを表示
- 筋トレ実施日の色分けを維持
EOF

git add pubspec.yaml lib/main.dart README.md oruso_v05_combined.sh
git commit -m "Upgrade ORUSO to Ver.0.5 with weekday and daily calendar details" || true
git push origin main

echo
echo "ORUSO Ver.0.5 combined update complete."

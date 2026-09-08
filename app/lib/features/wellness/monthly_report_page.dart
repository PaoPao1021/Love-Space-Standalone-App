import 'package:flutter/material.dart';

import 'wellness_repository.dart';

class MonthlyReportPage extends StatefulWidget {
  const MonthlyReportPage({required this.repository, super.key});
  final WellnessRepository repository;
  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<MonthlyReport> _report = _load();

  Future<MonthlyReport> _load() =>
      widget.repository.monthlyReport(_month.year, _month.month);

  void _move(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final current = DateTime(DateTime.now().year, DateTime.now().month);
    if (next.isAfter(current)) return;
    setState(() {
      _month = next;
      _report = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我们的月报')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FutureBuilder<MonthlyReport>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _report = _load()),
                    child: const Text('加载失败，点按重试'),
                  ),
                );
              }
              final report = snapshot.data!;
              final metrics = [
                ('一起记心情', '${report.moodDays} 天', Icons.mood_outlined),
                ('一起回答', '${report.questionDays} 天', Icons.forum_outlined),
                ('留下点滴', '${report.moments} 条', Icons.auto_awesome_outlined),
                ('点滴照片', '${report.photos} 张', Icons.photo_outlined),
                ('积分变化', '${report.points} 分', Icons.stars_outlined),
              ];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '上个月',
                        onPressed: () => _move(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        '${report.year} 年 ${report.month} 月',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        tooltip: '下个月',
                        onPressed:
                            DateTime(_month.year, _month.month + 1).isAfter(
                              DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                              ),
                            )
                            ? null
                            : () => _move(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Text(
                            '${report.connectionScore}',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const Text('本月默契值 / 100'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...metrics.map(
                    (item) => Card(
                      child: ListTile(
                        minTileHeight: 64,
                        leading: Icon(item.$3),
                        title: Text(item.$1),
                        trailing: Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

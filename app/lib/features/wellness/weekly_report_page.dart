import 'package:flutter/material.dart';

import 'wellness_repository.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({required this.repository, super.key});
  final WellnessRepository repository;

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  int _offset = 0;
  late Future<WeeklyFitnessReport> _report = _load();

  Future<WeeklyFitnessReport> _load() =>
      widget.repository.weeklyReport(_offset);

  void _select(int value) {
    setState(() {
      _offset = value;
      _report = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('双人健康周报')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: FutureBuilder<WeeklyFitnessReport>(
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
                ('有效运动', '${report.workouts} 次', Icons.directions_run_outlined),
                ('运动时间', '${report.totalMinutes} 分钟', Icons.timer_outlined),
                (
                  '训练消耗',
                  '${report.totalCalories} 千卡',
                  Icons.local_fire_department_outlined,
                ),
                (
                  '共同前进',
                  '${report.totalSteps} 步',
                  Icons.directions_walk_outlined,
                ),
                (
                  '记录天数',
                  '${report.activeDays} 天',
                  Icons.event_available_outlined,
                ),
              ];
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _report = _load());
                  await _report;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _offset,
                      decoration: const InputDecoration(labelText: '选择周次'),
                      items: List.generate(
                        8,
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text(
                            index == 0
                                ? '本周'
                                : index == 1
                                ? '上周'
                                : '$index 周前',
                          ),
                        ),
                      ),
                      onChanged: (value) => _select(value ?? 0),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_short(report.start)} — ${_short(report.end)}',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${report.teamScore}%',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              report.headline,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            const Text('比较各自的过去，不比较彼此。'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...metrics.map(
                      (metric) => Card(
                        child: ListTile(
                          minTileHeight: 62,
                          leading: Icon(metric.$3),
                          title: Text(metric.$1),
                          trailing: Text(
                            metric.$2,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '各自的节奏',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...report.members.map(
                      (member) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      member.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Text('${member.stats.progress}%'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: member.stats.progress / 100,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${member.stats.workouts} 次 · ${member.stats.minutes} 分钟 · ${member.stats.totalSteps} 步',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('本周最稳定：${report.bestHabit}'),
                            const SizedBox(height: 8),
                            Text(report.insight),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

String _short(DateTime value) => '${value.month}月${value.day}日';

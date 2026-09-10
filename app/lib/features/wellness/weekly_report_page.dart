import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    appBar: AppBar(toolbarHeight: 0),
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
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OUR HEALTH WEEK',
                                style: TextStyle(
                                  letterSpacing: 2.5,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF698471),
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '双人健康周报',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF29342E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int>(
                          value: _offset,
                          underline: const SizedBox(),
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: const Color(0xFF2B4337),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Row(
                          children: [
                            Container(
                              width: 94,
                              height: 94,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFA9CDB7),
                                  width: 7,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${report.teamScore}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const Text(
                                    '共同完成',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFA9CDB7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_short(report.start)} — ${_short(report.end)}',
                                    style: const TextStyle(
                                      color: Color(0xFFA8C8B3),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    report.headline,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '比较各自的过去，不比较彼此。',
                                    style: TextStyle(
                                      color: Color(0x99FFFFFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.only(top: 22, bottom: 10),
                      child: Text(
                        '这周一起做到',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, box) => GridView.count(
                        crossAxisCount: box.maxWidth > 600 ? 3 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.12,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: metrics.asMap().entries.map((entry) {
                          final metric = entry.value;
                          return Card(
                            elevation: 0,
                            color: entry.key == 0
                                ? const Color(0xFFE6EFE8)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    metric.$3,
                                    size: 18,
                                    color: const Color(0xFF60806C),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    metric.$2,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    metric.$1,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF929D96),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF60806C),
                        ),
                        title: const Text('本周最稳定的习惯'),
                        subtitle: Text(report.bestHabit),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '各自的节奏',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...report.members.map(
                      (member) => Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${member.name} · ${member.isMe ? '我的本周' : 'TA 的本周'}',
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
                                color: const Color(0xFF79A188),
                                backgroundColor: const Color(0xFFEDF0EC),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  _MemberMetric(
                                    '${member.stats.workouts}',
                                    '运动次数',
                                  ),
                                  _MemberMetric(
                                    '${member.stats.minutes}',
                                    '运动分钟',
                                  ),
                                  _MemberMetric(
                                    '${member.stats.totalSteps}',
                                    '本周步数',
                                  ),
                                  _MemberMetric(
                                    '${member.stats.calories}',
                                    '消耗大卡',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '趋势 · ${!member.stats.weightTrendVisible
                                    ? '体重数据保持私密'
                                    : member.stats.weightChange == null
                                    ? '本周还没有形成体重趋势'
                                    : member.stats.weightChange == 0
                                    ? '本周体重趋势保持稳定'
                                    : '本周趋势 ${member.stats.weightChange! > 0 ? '+' : ''}${member.stats.weightChange} kg'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF929D96),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: const Color(0xFF4B6757),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '下周建议',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              report.insight,
                              style: const TextStyle(color: Color(0xD9FFFFFF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        '数据不是评分。休息、恢复和真实记录，同样是计划的一部分。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF929D96),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go('/fitness');
                        }
                      },
                      child: const Text('返回一起变好'),
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

class _MemberMetric extends StatelessWidget {
  const _MemberMetric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xff929d96)),
      ),
    ],
  );
}

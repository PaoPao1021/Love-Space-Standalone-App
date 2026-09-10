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
    appBar: AppBar(toolbarHeight: 0),
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
                ('次坦诚问答', '${report.questionDays}', Icons.forum_outlined),
                ('天互相看见心情', '${report.moodDays}', Icons.mood_outlined),
                ('段共同回忆', '${report.moments}', Icons.auto_awesome_outlined),
                ('点爱心流动', '${report.points}', Icons.stars_outlined),
              ];
              return ListView(
                padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OUR MONTH',
                              style: TextStyle(
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA05A67),
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '你们的关系月报',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D2729),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '上个月',
                              onPressed: () => _move(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              '${_month.month} 月',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              tooltip: '下个月',
                              onPressed:
                                  DateTime(
                                    _month.year,
                                    _month.month + 1,
                                  ).isAfter(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: const Color(0xFF2B2527),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        children: [
                          Container(
                            width: 102,
                            height: 102,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE85D75),
                                width: 8,
                              ),
                            ),
                            child: Text(
                              '${report.connectionScore}',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '本月关系温度',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '本月默契值 / 100',
                                  style: TextStyle(color: Color(0xB3FFFFFF)),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '数据不是评分，是陪伴的痕迹。',
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
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 18, bottom: 12),
                    child: Text(
                      '一起完成',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, box) => GridView.count(
                      crossAxisCount: box.maxWidth > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: metrics.asMap().entries.map((entry) {
                        final item = entry.value;
                        return Card(
                          elevation: 0,
                          color: entry.key == 0
                              ? const Color(0xFFF8E4E8)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.$3,
                                  size: 18,
                                  color: const Color(0xFFA05A67),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  item.$1,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF756A6D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (report.topMood.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _moodEmoji(report.topMood),
                            style: const TextStyle(fontSize: 34),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '这个月最常出现的心情',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff9b9194),
                                ),
                              ),
                              Text(
                                _moodLabel(report.topMood),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (report.anniversaries.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text(
                      '本月纪念',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...report.anniversaries.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.name)),
                            Text(
                              item.date,
                              style: const TextStyle(color: Color(0xff756a6d)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 38, 24, 0),
                    child: Text(
                      '数据不是评分，是提醒我们曾经认真陪伴彼此。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFA79DA0), fontSize: 12),
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

String _moodEmoji(String mood) =>
    const {
      'happy': '😊',
      'love': '🥰',
      'calm': '😌',
      'excited': '🤩',
      'miss': '🥺',
      'grateful': '🙏',
      'tired': '😴',
      'anxious': '😰',
      'sad': '😢',
      'angry': '😤',
    }[mood] ??
    '💭';
String _moodLabel(String mood) =>
    const {
      'happy': '开心',
      'love': '甜蜜',
      'calm': '平静',
      'excited': '兴奋',
      'miss': '想念',
      'grateful': '感恩',
      'tired': '疲惫',
      'anxious': '焦虑',
      'sad': '委屈',
      'angry': '生气',
    }[mood] ??
    mood;

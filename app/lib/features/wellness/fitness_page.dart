import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'wellness_repository.dart';

class FitnessPage extends StatefulWidget {
  const FitnessPage({required this.repository, super.key});
  final WellnessRepository repository;

  @override
  State<FitnessPage> createState() => _FitnessPageState();
}

class _FitnessPageState extends State<FitnessPage> {
  late Future<FitnessDashboard> _dashboard = widget.repository.dashboard();

  void _reload() => setState(() => _dashboard = widget.repository.dashboard());

  Future<void> _startChallenge(FitnessChallengePreset preset) async {
    try {
      await widget.repository.createChallenge(preset.id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已发起“${preset.title}”')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _editGoal(FitnessDashboard dashboard) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _GoalEditor(repository: widget.repository, dashboard: dashboard),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(toolbarHeight: 0),
    body: SafeArea(
      child: FutureBuilder<FitnessDashboard>(
        future: _dashboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: _reload,
                child: const Text('加载失败，点按重试'),
              ),
            );
          }
          final dashboard = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _dashboard;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BETTER TOGETHER',
                                    style: TextStyle(
                                      letterSpacing: 2,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF698471),
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '一起变好',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF26312B),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    '奖励坚持，不比较体重',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF929D96),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/fitness-report'),
                              child: const Text('周报 ↗'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Card(
                          color: const Color(0xFF2B4337),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '本周双人进度',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${dashboard.teamProgress}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: dashboard.teamProgress / 100,
                                  color: const Color(0xFF9CC9AA),
                                  backgroundColor: Colors.white24,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '共同进度，不做输赢排名',
                                  style: TextStyle(
                                    color: Color(0xB3FFFFFF),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Divider(color: Color(0x24FFFFFF)),
                                const SizedBox(height: 10),
                                _HeroMember(
                                  name: '我',
                                  stats: dashboard.myStats,
                                ),
                                const SizedBox(height: 8),
                                _HeroMember(
                                  name: 'TA',
                                  stats: dashboard.partnerStats,
                                  awaiting: dashboard.partnerStats == null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SectionHead(
                          kicker: 'MY PLAN',
                          title: '我的健康目标',
                          action: dashboard.goalConfigured ? '调整' : '设置',
                          onAction: () => _editGoal(dashboard),
                        ),
                        Card(
                          elevation: 0,
                          color: const Color(0xFFFFFFFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onTap: () => _editGoal(dashboard),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6EFE8),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(_goalLabel(dashboard.goalType)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      '${dashboard.weeklyWorkouts} 次 / 周运动\n${dashboard.dailySteps} 步 / 日',
                                      style: const TextStyle(
                                        height: 1.7,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _privacyLabel(dashboard.privacy),
                                    style: const TextStyle(
                                      color: Color(0xFF929D96),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SectionHead(
                          kicker: 'TODAY',
                          title: '今天的记录',
                          action: dashboard.partnerCheckedIn
                              ? 'TA 已打卡'
                              : '等待 TA',
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cards = [
                              _StatsCard(label: '我', stats: dashboard.myStats),
                              _StatsCard(
                                label: 'TA',
                                stats: dashboard.partnerStats,
                                checkedToday: dashboard.partnerCheckedIn,
                              ),
                            ];
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: cards
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: item,
                                      ),
                                    )
                                    .toList(),
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cards
                                  .map(
                                    (item) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        child: item,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        if (dashboard.todayCheckin != null) ...[
                          const SizedBox(height: 4),
                          _TodaySnapshot(checkin: dashboard.todayCheckin!),
                        ],
                        const SizedBox(height: 6),
                        _InlineCheckin(
                          repository: widget.repository,
                          existing: dashboard.todayCheckin,
                          onSaved: _reload,
                        ),
                        const SizedBox(height: 22),
                        _SectionHead(
                          kicker: 'PARTNER TODAY',
                          title: 'TA 今天的运动',
                          action: dashboard.partnerCheckedIn
                              ? 'TA 已打卡'
                              : '等待 TA',
                        ),
                        _PartnerToday(
                          checkin: dashboard.partnerToday,
                          checkedIn: dashboard.partnerCheckedIn,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _editGoal(dashboard),
                          icon: const Icon(Icons.tune_rounded),
                          label: Text(
                            dashboard.goalConfigured ? '调整我的目标' : '设置我的健康目标',
                          ),
                        ),
                        const SizedBox(height: 22),
                        _NutritionCard(plan: dashboard.nutritionPlan),
                        const SizedBox(height: 24),
                        _SectionHead(
                          kicker: 'CHALLENGES',
                          title: '双人挑战',
                          action: '发起挑战',
                        ),
                        const SizedBox(height: 10),
                        if (dashboard.challenges.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Text('还没有进行中的挑战，选一个轻松开始。'),
                            ),
                          )
                        else
                          ...dashboard.challenges.map(
                            (challenge) => _ChallengeCard(challenge: challenge),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dashboard.challengePresets
                              .map(
                                (preset) => ActionChip(
                                  avatar: const Icon(Icons.flag_outlined),
                                  label: Text(preset.title),
                                  onPressed: () => _startChallenge(preset),
                                ),
                              )
                              .toList(),
                        ),
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
  );
}

String _goalLabel(String value) => switch (value) {
  'fat-loss' => '减脂',
  'muscle' => '增肌',
  _ => '塑形',
};

String _privacyLabel(String value) => switch (value) {
  'shared' => '双方可见',
  'private' => '仅自己可见',
  _ => '仅分享趋势',
};

class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.kicker,
    required this.title,
    required this.action,
    this.onAction,
  });
  final String kicker;
  final String title;
  final String action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker,
                style: const TextStyle(
                  letterSpacing: 2,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF698471),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF26312B),
                ),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.plan});
  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_outlined),
              const SizedBox(width: 10),
              Text('今日饮食参考', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          if (!plan.ready)
            Text(plan.message.isEmpty ? '填写当前体重后生成个性化参考。' : plan.message)
          else ...[
            if (plan.intensity.isNotEmpty)
              Text(
                plan.intensity,
                style: const TextStyle(
                  color: Color(0xff698471),
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              '${plan.calories} 千卡',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.macros
                  .map(
                    (macro) =>
                        Chip(label: Text('${macro.name} ${macro.grams}g')),
                  )
                  .toList(),
            ),
            if (plan.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.summary),
            ],
            if (plan.bmr != null || plan.bmrMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff4f6f2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.bmr == null
                          ? '完成基础代谢计算'
                          : '基础代谢估算 ${plan.bmr} 大卡 / 日',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      plan.bmr == null ? plan.bmrMessage : plan.bmrNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff77837b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (plan.foodGroups.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '怎么吃更容易做到',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...plan.foodGroups.map((group) => _FoodGroupRow(group: group)),
            ],
            if (plan.disclaimer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.disclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

class _PartnerToday extends StatelessWidget {
  const _PartnerToday({this.checkin, required this.checkedIn});
  final DailyCheckin? checkin;
  final bool checkedIn;
  @override
  Widget build(BuildContext context) {
    final value = checkin;
    if (value == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(checkedIn ? 'TA 今天记录了休息日' : 'TA 今天还没有保存运动记录'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value.minutes} 分钟 · ${value.calories} 大卡',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (value.workouts.isEmpty)
            const Text('TA 今天记录了休息日')
          else
            ...value.workouts.map(
              (w) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${w.type} · ${w.startTime} · ${w.minutes} 分钟 · ${w.calories} 大卡',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodGroupRow extends StatelessWidget {
  const _FoodGroupRow({required this.group});
  final NutritionFoodGroup group;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff4f6f2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(group.foods, style: const TextStyle(fontSize: 12)),
          Text(
            group.note,
            style: const TextStyle(fontSize: 11, color: Color(0xff77837b)),
          ),
        ],
      ),
    ),
  );
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});
  final FitnessChallenge challenge;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${challenge.percent}%'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: challenge.percent / 100),
          const SizedBox(height: 8),
          Text('${challenge.current} / ${challenge.target} ${challenge.unit}'),
        ],
      ),
    ),
  );
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.label,
    this.stats,
    this.checkedToday = false,
  });
  final String label;
  final FitnessStats? stats;
  final bool checkedToday;

  @override
  Widget build(BuildContext context) {
    final value = stats;
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (label == 'TA')
                  Chip(label: Text(checkedToday ? '今日已记录' : '今日未记录')),
              ],
            ),
            if (value == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('等待 TA 加入'),
              )
            else ...[
              const SizedBox(height: 12),
              Text('个人进度 ${value.progress}%'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${value.workouts} 次运动')),
                  Chip(label: Text('${value.minutes} 分钟')),
                  Chip(label: Text('${value.totalSteps} 步')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroMember extends StatelessWidget {
  const _HeroMember({
    required this.name,
    required this.stats,
    this.awaiting = false,
  });
  final String name;
  final FitnessStats? stats;
  final bool awaiting;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0x22FFFFFF),
        child: Text(
          name == '我' ? '我' : 'TA',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          awaiting
              ? '等待 TA 加入'
              : '$name · ${stats!.workouts} 次 · ${stats!.minutes} 分钟 · ${stats!.progress}%',
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
        ),
      ),
    ],
  );
}

class _TodaySnapshot extends StatelessWidget {
  const _TodaySnapshot({required this.checkin});
  final DailyCheckin checkin;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xffeef4ef),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '我的今日记录',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xff375344),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${checkin.workoutType} · ${checkin.minutes} 分钟  |  ${checkin.steps} 步 · ${checkin.water} 杯水 · ${checkin.sleep} 小时睡眠',
          style: const TextStyle(fontSize: 12, color: Color(0xff5d7063)),
        ),
        Text(
          checkin.healthyMeal ? '今天吃得符合计划' : '今天按真实情况记录',
          style: const TextStyle(fontSize: 12, color: Color(0xff5d7063)),
        ),
      ],
    ),
  );
}

class _InlineCheckin extends StatefulWidget {
  const _InlineCheckin({
    required this.repository,
    required this.onSaved,
    this.existing,
  });
  final WellnessRepository repository;
  final DailyCheckin? existing;
  final VoidCallback onSaved;
  @override
  State<_InlineCheckin> createState() => _InlineCheckinState();
}

class _InlineCheckinState extends State<_InlineCheckin> {
  late final List<_WorkoutDraft> _workouts =
      (widget.existing?.workouts ?? const [])
          .map(_WorkoutDraft.fromEntry)
          .toList();
  late final _steps = TextEditingController(
    text: widget.existing?.steps.toString() ?? '0',
  );
  late final _water = TextEditingController(
    text: widget.existing?.water.toString() ?? '0',
  );
  late final _sleep = TextEditingController(
    text: widget.existing?.sleep.toString() ?? '0',
  );
  late final _weight = TextEditingController(
    text: widget.existing?.weight?.toString() ?? '',
  );
  late bool _healthyMeal = widget.existing?.healthyMeal ?? false;
  bool _saving = false;
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.checkInWorkouts(
        workouts: _workouts.map((item) => item.toEntry()).toList(),
        steps: int.tryParse(_steps.text) ?? 0,
        water: int.tryParse(_water.text) ?? 0,
        sleep: double.tryParse(_sleep.text) ?? 0,
        healthyMeal: _healthyMeal,
        weight: double.tryParse(_weight.text),
      );
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今日记录已保存')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final workout in _workouts) {
      workout.dispose();
    }
    _steps.dispose();
    _water.dispose();
    _sleep.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '运动记录',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          const Text(
            '记录真实状态，休息也是计划的一部分。',
            style: TextStyle(fontSize: 12, color: Color(0xff77837b)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '训练记录',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _workouts.length >= 12
                    ? null
                    : () => setState(
                        () => _workouts.add(_WorkoutDraft(type: 'walk')),
                      ),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('添加'),
              ),
            ],
          ),
          if (_workouts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '今天暂未添加运动，休息也是计划的一部分。',
                style: TextStyle(color: Color(0xff77837b), fontSize: 12),
              ),
            ),
          ..._workouts.asMap().entries.map(
            (entry) => _WorkoutRow(
              draft: entry.value,
              index: entry.key,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() {
                entry.value.dispose();
                _workouts.removeAt(entry.key);
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _number(_steps, '今日步数')),
              const SizedBox(width: 10),
              Expanded(child: _number(_water, '饮水杯数')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sleep,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '睡眠小时'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '体重（可选）',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _healthyMeal,
            onChanged: (value) => setState(() => _healthyMeal = value),
            title: const Text('今天吃得符合计划'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存今日记录'),
          ),
        ],
      ),
    ),
  );
  static Widget _number(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );
}

class _WorkoutDraft {
  _WorkoutDraft({
    required this.type,
    String? id,
    String? startTime,
    String minutes = '',
    String calories = '',
  }) : id = id ?? 'workout-${DateTime.now().microsecondsSinceEpoch}',
       startTime = TextEditingController(text: startTime ?? _nowTime()),
       minutes = TextEditingController(text: minutes),
       calories = TextEditingController(text: calories);
  _WorkoutDraft.fromEntry(WorkoutEntry entry)
    : this(
        id: entry.id,
        type: entry.type,
        startTime: entry.startTime,
        minutes: '${entry.minutes}',
        calories: '${entry.calories}',
      );
  final String id;
  String type;
  final TextEditingController startTime;
  final TextEditingController minutes;
  final TextEditingController calories;
  WorkoutEntry toEntry() => WorkoutEntry(
    id: id,
    type: type,
    startTime: startTime.text.trim(),
    minutes: int.tryParse(minutes.text) ?? 0,
    calories: int.tryParse(calories.text) ?? 0,
  );
  void dispose() {
    startTime.dispose();
    minutes.dispose();
    calories.dispose();
  }

  static String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });
  final _WorkoutDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xfff4f6f2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xff698471),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: draft.type,
                isDense: true,
                decoration: const InputDecoration(labelText: '运动类型'),
                items: const [
                  DropdownMenuItem(value: 'walk', child: Text('步行')),
                  DropdownMenuItem(value: 'run', child: Text('跑步')),
                  DropdownMenuItem(value: 'strength', child: Text('力量训练')),
                  DropdownMenuItem(value: 'cycle', child: Text('骑行')),
                  DropdownMenuItem(value: 'yoga', child: Text('瑜伽')),
                  DropdownMenuItem(value: 'swim', child: Text('游泳')),
                  DropdownMenuItem(value: 'other', child: Text('其他运动')),
                ],
                onChanged: (v) {
                  draft.type = v ?? 'walk';
                  onChanged();
                },
              ),
            ),
            IconButton(
              tooltip: '删除训练',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: draft.startTime,
                readOnly: true,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    draft.startTime.text =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    onChanged();
                  }
                },
                decoration: const InputDecoration(labelText: '开始时间'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: draft.minutes,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '分钟'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: draft.calories,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '大卡'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({required this.repository, required this.dashboard});
  final WellnessRepository repository;
  final FitnessDashboard dashboard;
  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late String _goal = widget.dashboard.goalType;
  late String _privacy = widget.dashboard.privacy;
  late double _workouts = widget.dashboard.weeklyWorkouts.toDouble();
  late double _steps = widget.dashboard.dailySteps.toDouble();
  late final _currentWeight = TextEditingController(
    text: widget.dashboard.currentWeight?.toString() ?? '',
  );
  late final _targetWeight = TextEditingController(
    text: widget.dashboard.targetWeight?.toString() ?? '',
  );
  late final _height = TextEditingController(
    text: widget.dashboard.height?.toString() ?? '',
  );
  late final _age = TextEditingController(
    text: widget.dashboard.age?.toString() ?? '',
  );
  late String _biologicalSex = widget.dashboard.biologicalSex;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveGoal(
        goalType: _goal,
        weeklyWorkouts: _workouts.round(),
        dailySteps: _steps.round(),
        privacy: _privacy,
        currentWeight: double.tryParse(_currentWeight.text),
        targetWeight: double.tryParse(_targetWeight.text),
        height: double.tryParse(_height.text),
        age: int.tryParse(_age.text),
        biologicalSex: _biologicalSex,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _currentWeight.dispose();
    _targetWeight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('我的健康目标', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: '目标'),
            items: const [
              DropdownMenuItem(value: 'fat-loss', child: Text('减脂与健康')),
              DropdownMenuItem(value: 'muscle', child: Text('增肌与力量')),
              DropdownMenuItem(value: 'shape', child: Text('塑形与体态')),
            ],
            onChanged: (value) => _goal = value ?? 'fat-loss',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _currentWeight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '当前体重',
                    suffixText: 'kg',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _targetWeight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '目标体重',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('基础代谢参数（填写其中一项时需全部填写）'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '身高',
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '年龄'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _biologicalSex.isEmpty ? null : _biologicalSex,
            decoration: const InputDecoration(labelText: '生理性别（用于代谢估算）'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('男性公式')),
              DropdownMenuItem(value: 'female', child: Text('女性公式')),
            ],
            onChanged: (value) => _biologicalSex = value ?? '',
          ),
          const SizedBox(height: 16),
          Text('每周运动 ${_workouts.round()} 次'),
          Slider(
            min: 1,
            max: 7,
            divisions: 6,
            value: _workouts,
            onChanged: (value) => setState(() => _workouts = value),
          ),
          Text('每日步数 ${_steps.round()}'),
          Slider(
            min: 1000,
            max: 50000,
            divisions: 49,
            value: _steps.clamp(1000, 50000),
            onChanged: (value) => setState(() => _steps = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _privacy,
            decoration: const InputDecoration(labelText: 'TA 可以看到'),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('仅完成情况')),
              DropdownMenuItem(value: 'trend', child: Text('完成情况与体重趋势')),
              DropdownMenuItem(value: 'shared', child: Text('全部目标数据')),
            ],
            onChanged: (value) => _privacy = value ?? 'trend',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存目标'),
          ),
        ],
      ),
    ),
  );
}

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

  Future<void> _checkIn(FitnessDashboard dashboard) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CheckinEditor(
        repository: widget.repository,
        existing: dashboard.todayCheckin,
      ),
    );
    if (changed == true) _reload();
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
    appBar: AppBar(
      title: const Text('一起变好'),
      actions: [
        IconButton(
          tooltip: '查看健康周报',
          onPressed: () => context.push('/fitness-report'),
          icon: const Icon(Icons.assessment_outlined),
        ),
      ],
    ),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '本周双人进度',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${dashboard.teamProgress}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: dashboard.teamProgress / 100,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          onPressed: () => _checkIn(dashboard),
                          icon: const Icon(Icons.add_chart_rounded),
                          label: Text(
                            dashboard.todayCheckin == null ? '记录今天' : '更新今天的记录',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _editGoal(dashboard),
                          icon: const Icon(Icons.tune_rounded),
                          label: Text(
                            dashboard.goalConfigured ? '调整我的目标' : '设置我的健康目标',
                          ),
                        ),
                        const SizedBox(height: 18),
                        _NutritionCard(plan: dashboard.nutritionPlan),
                        const SizedBox(height: 24),
                        Text(
                          '双人挑战',
                          style: Theme.of(context).textTheme.titleLarge,
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

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.plan});
  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) => Card(
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

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});
  final FitnessChallenge challenge;

  @override
  Widget build(BuildContext context) => Card(
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

class _CheckinEditor extends StatefulWidget {
  const _CheckinEditor({required this.repository, this.existing});
  final WellnessRepository repository;
  final DailyCheckin? existing;
  @override
  State<_CheckinEditor> createState() => _CheckinEditorState();
}

class _CheckinEditorState extends State<_CheckinEditor> {
  late final _minutes = TextEditingController(
    text: widget.existing?.minutes.toString() ?? '0',
  );
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
  late String _type = widget.existing?.workoutType ?? 'rest';
  late bool _healthyMeal = widget.existing?.healthyMeal ?? false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final minutes = int.tryParse(_minutes.text) ?? 0;
      await widget.repository.checkIn(
        workoutType: minutes > 0 ? _type : 'rest',
        minutes: minutes,
        calories: minutes > 0 ? minutes * 5 : 0,
        steps: int.tryParse(_steps.text) ?? 0,
        water: int.tryParse(_water.text) ?? 0,
        sleep: double.tryParse(_sleep.text) ?? 0,
        healthyMeal: _healthyMeal,
        weight: double.tryParse(_weight.text),
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
    _minutes.dispose();
    _steps.dispose();
    _water.dispose();
    _sleep.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('今天的健康记录', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '主要运动'),
            items: const [
              DropdownMenuItem(value: 'rest', child: Text('休息日')),
              DropdownMenuItem(value: 'walk', child: Text('步行')),
              DropdownMenuItem(value: 'run', child: Text('跑步')),
              DropdownMenuItem(value: 'strength', child: Text('力量训练')),
              DropdownMenuItem(value: 'cycle', child: Text('骑行')),
              DropdownMenuItem(value: 'yoga', child: Text('瑜伽')),
              DropdownMenuItem(value: 'swim', child: Text('游泳')),
              DropdownMenuItem(value: 'other', child: Text('其他运动')),
            ],
            onChanged: (value) => _type = value ?? 'rest',
          ),
          const SizedBox(height: 10),
          _numberField(_minutes, '运动分钟', 600),
          const SizedBox(height: 10),
          _numberField(_steps, '今日步数', 100000),
          const SizedBox(height: 10),
          _numberField(_water, '饮水杯数', 20),
          const SizedBox(height: 10),
          TextField(
            controller: _sleep,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '睡眠小时'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '今日体重（可选）',
              suffixText: 'kg',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _healthyMeal,
            onChanged: (value) => setState(() => _healthyMeal = value),
            title: const Text('今天吃得比较健康'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存今日记录'),
          ),
        ],
      ),
    ),
  );

  static Widget _numberField(
    TextEditingController controller,
    String label,
    int maximum,
  ) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, helperText: '0–$maximum'),
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

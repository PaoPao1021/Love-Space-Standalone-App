import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../memories/memories_models.dart';
import '../memories/memories_repository.dart';
import '../wellness/wellness_repository.dart';
import 'together_models.dart';
import 'together_repository.dart';

class TogetherHubPage extends StatefulWidget {
  const TogetherHubPage({
    required this.repository,
    required this.memoriesRepository,
    required this.wellnessRepository,
    super.key,
  });
  final TogetherRepository repository;
  final MemoriesRepository memoriesRepository;
  final WellnessRepository wellnessRepository;

  @override
  State<TogetherHubPage> createState() => _TogetherHubPageState();
}

class _TogetherHubPageState extends State<TogetherHubPage> {
  late Future<_TogetherSummary> _summary = _load();

  Future<_TogetherSummary> _load() async {
    final values = await Future.wait([
      widget.repository.tasks(status: 'pending'),
      widget.repository.dishes(),
      widget.repository.score(),
      widget.memoriesRepository.wishes(),
      widget.memoriesRepository.capsules(),
    ]);
    return _TogetherSummary(
      pendingTasks: (values[0] as List<CoupleTask>).length,
      dishes: (values[1] as List<Dish>).length,
      myPoints: (values[2] as PointScore).mine,
      openWishes: (values[3] as List<WishEntry>)
          .where((item) => item.status != 'done')
          .length,
      lockedCapsules: (values[4] as CapsuleList).locked.length,
    );
  }

  Future<void> _refresh() async {
    setState(() => _summary = _load());
    try {
      await _summary;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('一起做')),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text(
              '把生活里的小事，变成两个人的默契。',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '任务完成会自动发放奖励；点菜订单和积分变化会同步给对方。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            FutureBuilder<_TogetherSummary>(
              future: _summary,
              builder: (context, snapshot) => LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _HubCard(
                      icon: Icons.task_alt_outlined,
                      title: '共同任务',
                      value: snapshot.hasError
                          ? '点按重试'
                          : snapshot.hasData
                          ? '${snapshot.data!.pendingTasks} 项待完成'
                          : '正在读取…',
                      description: '分配、完成并自动获得积分',
                      onTap: snapshot.hasError
                          ? _refresh
                          : () => context.push('/tasks'),
                    ),
                    _HubCard(
                      icon: Icons.restaurant_menu_outlined,
                      title: '今天吃什么',
                      value: snapshot.hasData
                          ? '${snapshot.data!.dishes} 道收藏'
                          : '整理你们的菜单',
                      description: '挑菜、下单与回看历史',
                      onTap: () => context.push('/menu'),
                    ),
                    _HubCard(
                      icon: Icons.stars_outlined,
                      title: '甜蜜积分',
                      value: snapshot.hasData
                          ? '我的 ${snapshot.data!.myPoints} 分'
                          : '记录彼此的付出',
                      description: '赠送积分并兑换小奖励',
                      onTap: () => context.push('/points'),
                    ),
                    _HubCard(
                      icon: Icons.favorite_border_rounded,
                      title: '我们的愿望',
                      value: snapshot.hasData
                          ? '${snapshot.data!.openWishes} 个等待实现'
                          : '收藏共同的期待',
                      description: '从想做、进行中到一起实现',
                      onTap: () => context.push('/wishes'),
                    ),
                    _HubCard(
                      icon: Icons.lock_clock_outlined,
                      title: '时光胶囊',
                      value: snapshot.hasData
                          ? '${snapshot.data!.lockedCapsules} 封等待开启'
                          : '写给未来的我们',
                      description: '到约定日期再揭开内容',
                      onTap: () => context.push('/capsules'),
                    ),
                    _HubCard(
                      icon: Icons.directions_run_outlined,
                      title: '一起变好',
                      value: '记录今天的健康节奏',
                      description: '运动、步数与双人周进度',
                      onTap: () => context.push('/fitness'),
                    ),
                    _HubCard(
                      icon: Icons.insights_outlined,
                      title: '我们的月报',
                      value: '回看这个月的默契',
                      description: '问答、心情、点滴与积分汇总',
                      onTap: () => context.push('/monthly-report'),
                    ),
                    _HubCard(
                      icon: Icons.psychology_alt_outlined,
                      title: '默契测试',
                      value: '分别回答，再一起揭晓',
                      description: '答案在双方提交前保持隐藏',
                      onTap: () => context.push('/quiz'),
                    ),
                    _HubCard(
                      icon: Icons.volunteer_activism_outlined,
                      title: '感谢墙',
                      value: '把温暖的小事说出来',
                      description: '记录那些值得被看见的付出',
                      onTap: () => context.push('/thanks'),
                    ),
                    _HubCard(
                      icon: Icons.timeline_rounded,
                      title: '回忆时间轴',
                      value: '按月份回看共同经历',
                      description: '也可以随机抽取一段旧时光',
                      onTap: () => context.push('/timeline'),
                    ),
                  ];
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: cards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  }
                  final width = (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map((card) => SizedBox(width: width, child: card))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 156),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TogetherSummary {
  const _TogetherSummary({
    required this.pendingTasks,
    required this.dishes,
    required this.myPoints,
    required this.openWishes,
    required this.lockedCapsules,
  });
  final int pendingTasks;
  final int dishes;
  final int myPoints;
  final int openWishes;
  final int lockedCapsules;
}

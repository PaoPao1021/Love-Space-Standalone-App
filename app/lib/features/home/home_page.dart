import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_models.dart';
import '../../theme/lovespace_theme.dart';
import '../anniversary/anniversary.dart';
import '../anniversary/anniversary_repository.dart';
import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.user,
    required this.anniversaryRepository,
    required this.coreLoopRepository,
    super.key,
  });
  final LoveSpaceUser? user;
  final AnniversaryRepository anniversaryRepository;
  final CoreLoopRepository coreLoopRepository;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Anniversary>> _anniversaries;
  late Future<DailyQuestion> _question;
  late Future<MoodEntry?> _myMood;
  late Future<MoodEntry?> _partnerMood;
  late Future<int> _unread;
  late Future<MomentPageResult> _moments;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _anniversaries = widget.anniversaryRepository.list();
    _question = widget.coreLoopRepository.getDailyQuestion();
    _myMood = widget.coreLoopRepository.getMyMood();
    _partnerMood = widget.coreLoopRepository.getPartnerMood();
    _unread = widget.coreLoopRepository.unreadCount();
    _moments = widget.coreLoopRepository.moments();
  }

  Future<void> _refresh() async {
    setState(_reload);
    for (final future in [
      _anniversaries,
      _question,
      _myMood,
      _partnerMood,
      _unread,
      _moments,
    ]) {
      try {
        await future;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user?.displayName ?? '你';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今天也要好好相爱',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '你好，$name',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<int>(
                    future: _unread,
                    builder: (context, snapshot) => Badge(
                      isLabelVisible: (snapshot.data ?? 0) > 0,
                      label: Text('${snapshot.data ?? 0}'),
                      child: IconButton(
                        tooltip: '通知中心',
                        onPressed: () => context
                            .push('/notifications')
                            .then(
                              (_) => setState(
                                () => _unread = widget.coreLoopRepository
                                    .unreadCount(),
                              ),
                            ),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFFD7E7),
                    foregroundImage:
                        (widget.user?.avatarUrl.isNotEmpty ?? false)
                        ? NetworkImage(widget.user!.avatarUrl)
                        : null,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: LoveSpaceColors.rose,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<List<Anniversary>>(
                future: _anniversaries,
                builder: (context, snapshot) => _AnniversaryHero(
                  anniversary: snapshot.data?.firstOrNull,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  failed: snapshot.hasError,
                  onTap: () => context
                      .push('/anniversaries')
                      .then(
                        (_) => setState(
                          () => _anniversaries = widget.anniversaryRepository
                              .list(),
                        ),
                      ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<DailyQuestion>(
                future: _question,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  final subtitle = item == null
                      ? (snapshot.hasError ? '暂时无法读取，点按重试' : '正在准备今天的问题…')
                      : item.bothAnswered
                      ? '双方已回答，点击揭晓'
                      : item.myAnswer == null
                      ? '等待你回答'
                      : item.partnerAnswered
                      ? 'TA 已回答，完成后一起揭晓'
                      : '已提交，等待 TA';
                  return _WideCard(
                    icon: Icons.forum_outlined,
                    eyebrow: item?.category ?? '每日问答',
                    title: item?.question ?? '今天想更了解彼此一点',
                    subtitle: subtitle,
                    onTap: () => context
                        .push('/daily-question')
                        .then(
                          (_) => setState(
                            () => _question = widget.coreLoopRepository
                                .getDailyQuestion(),
                          ),
                        ),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: FutureBuilder<MoodEntry?>(
                      future: _myMood,
                      builder: (_, snapshot) => _MoodCard(
                        label: '我的心情',
                        mood: snapshot.data,
                        onTap: _openMood,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<MoodEntry?>(
                      future: _partnerMood,
                      builder: (_, snapshot) => _MoodCard(
                        label: 'TA 的心情',
                        mood: snapshot.data,
                        onTap: _openMood,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '最近点滴',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/moments'),
                    child: const Text('查看全部'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<MomentPageResult>(
                future: _moments,
                builder: (context, snapshot) {
                  final item = snapshot.data?.items.firstOrNull;
                  if (item == null) {
                    return _WideCard(
                      icon: Icons.auto_awesome_outlined,
                      eyebrow: '共同记录',
                      title: '还没有点滴',
                      subtitle: snapshot.hasError
                          ? '网络恢复后再试，文字草稿会一直保留'
                          : '写下你们的第一段日常',
                      onTap: () => context.go('/moments'),
                    );
                  }
                  return _WideCard(
                    icon: Icons.auto_awesome_outlined,
                    eyebrow: item.tags.firstOrNull ?? '生活片段',
                    title: item.title.isEmpty ? '我们的最近一刻' : item.title,
                    subtitle: item.content.isEmpty
                        ? '有 ${item.images.length} 张照片'
                        : item.content,
                    onTap: () => context.go('/moments'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMood() async {
    await context.push('/mood');
    setState(() {
      _myMood = widget.coreLoopRepository.getMyMood();
      _partnerMood = widget.coreLoopRepository.getPartnerMood();
    });
  }
}

class _AnniversaryHero extends StatelessWidget {
  const _AnniversaryHero({
    required this.anniversary,
    required this.loading,
    required this.failed,
    required this.onTap,
  });
  final Anniversary? anniversary;
  final bool loading;
  final bool failed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final item = anniversary;
    final description = failed
        ? '暂时无法读取，点按重试'
        : item == null
        ? '等待一起记录'
        : item.daysFrom() == 0
        ? '就是今天'
        : item.daysFrom() > 0
        ? '还有 ${item.daysFrom()} 天'
        : '已经过去 ${item.daysFrom().abs()} 天';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFBE185D), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38BE185D),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  failed ? Icons.refresh_rounded : Icons.favorite_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 26),
                Text(
                  item?.name ?? '我们的纪念日',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  loading ? '正在读取…' : description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.label,
    required this.mood,
    required this.onTap,
  });
  final String label;
  final MoodEntry? mood;
  final VoidCallback onTap;
  static const labels = {
    'happy': '开心',
    'love': '心动',
    'calm': '平静',
    'excited': '兴奋',
    'miss': '想念',
    'grateful': '感恩',
    'tired': '疲惫',
    'anxious': '焦虑',
    'sad': '难过',
    'angry': '生气',
  };
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              mood == null
                  ? Icons.mood_outlined
                  : Icons.favorite_border_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 3),
            Text(
              mood == null ? '等待记录' : labels[mood!.type] ?? mood!.type,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
      ),
    ),
  );
}

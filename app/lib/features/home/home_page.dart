import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/living_surface.dart';
import '../../core/auth/auth_models.dart';
import '../anniversary/anniversary.dart';
import '../anniversary/anniversary_repository.dart';
import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';
import '../wellness/wellness_repository.dart';

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
  List<Anniversary> _anniversaries = [];
  List<MomentEntry> _moments = [];
  List<AppNotification> _notices = [];
  DailyQuestion? _question;
  MoodEntry? _mine;
  MoodEntry? _theirMood;
  FitnessDashboard? _fitness;
  Map<String, dynamic> _couple = {}, _partner = {};
  int? _energy;
  final Set<String> _errors = {};
  bool _loading = true;
  int _generation = 0;
  static const rose = Color(0xFFE85D75);
  static const muted = Color(0xFF9A8F92);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final repo = widget.coreLoopRepository;
    Future<void> read<T>(
      String name,
      Future<T> request,
      void Function(T) apply,
    ) async {
      try {
        final result = await request;
        if (mounted && generation == _generation) {
          setState(() {
            apply(result);
            _errors.remove(name);
          });
        }
      } catch (_) {
        if (mounted && generation == _generation) {
          setState(() => _errors.add(name));
        }
      }
    }

    await Future.wait([
      read(
        '空间',
        repo.apiClient.post(
          '/api/v1/functions/couple',
          body: const {'action': 'getInfo'},
        ),
        (data) {
          _couple = (data['couple'] as Map<String, dynamic>?) ?? {};
          _partner = (data['partner'] as Map<String, dynamic>?) ?? {};
        },
      ),
      read(
        '纪念日',
        widget.anniversaryRepository.list(),
        (value) => _anniversaries = value,
      ),
      read('每日问答', repo.getDailyQuestion(), (value) => _question = value),
      read('我的心情', repo.getMyMood(), (value) => _mine = value),
      read('对方心情', repo.getPartnerMood(), (value) => _theirMood = value),
      read(
        '回忆',
        repo.moments(),
        (value) => _moments = value.items.take(3).toList(),
      ),
      read(
        '通知',
        repo.notifications(),
        (value) =>
            _notices = value.items.where((item) => !item.read).take(2).toList(),
      ),
      read(
        '健康',
        WellnessRepository(apiClient: repo.apiClient).dashboard(),
        (value) => _fitness = value,
      ),
      read(
        '能量',
        repo.apiClient.post(
          '/api/v1/functions/points',
          body: const {'action': 'getScore'},
        ),
        (value) {
          final total =
              ((value['myScore'] as num?) ?? 0) +
              ((value['partnerScore'] as num?) ?? 0);
          _energy = (total / 20).round().clamp(0, 100);
        },
      ),
    ]);
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _reload();
  }

  static const _moods = {
    'happy': ('😊', '开心'),
    'love': ('🥰', '甜蜜'),
    'calm': ('😌', '平静'),
    'excited': ('🤩', '兴奋'),
    'miss': ('🥺', '想念'),
    'grateful': ('🙏', '感恩'),
    'tired': ('😴', '疲惫'),
    'anxious': ('😰', '焦虑'),
    'sad': ('😢', '委屈'),
    'angry': ('😤', '生气'),
  };
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，记得好好休息';
    if (hour < 11) return '早安，今天也好好相爱';
    if (hour < 14) return '午间好，留一点时间给彼此';
    if (hour < 18) return '下午好，分享今天的小事吧';
    if (hour < 22) return '晚上好，聊聊今天的心情';
    return '晚安，把今天温柔收好';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _couple.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LoveSpace',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(width: 48, child: LinearProgressIndicator(minHeight: 2)),
            SizedBox(height: 14),
            Text('正在打开你们的空间', style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      );
    }
    final upcoming = _anniversaries.where((a) => a.daysFrom() >= 0).toList()
      ..sort((a, b) => a.daysFrom().compareTo(b.daysFrom()));
    final next = upcoming.firstOrNull;
    final start = DateTime.tryParse(_couple['startDate']?.toString() ?? '');
    final now = DateTime.now();
    final days = start == null
        ? null
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).difference(DateTime(start.year, start.month, start.day)).inDays;
    final mine = _moods[_mine?.type], theirs = _moods[_theirMood?.type];
    final moodText = mine != null && theirs != null
        ? '${mine.$2} / ${theirs.$2}'
        : mine != null
        ? '我：${mine.$2}'
        : theirs != null
        ? 'TA：${theirs.$2}'
        : '今天还没有打卡';
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LoveSpace',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 4.5),
                      _text(_greeting, size: 11),
                    ],
                  ),
                ),
                SizedBox(
                  width: 62,
                  height: 35,
                  child: Stack(
                    children: [
                      _avatar(widget.user?.avatarUrl ?? ''),
                      Positioned(
                        left: 24,
                        child: _avatar(_partner['avatarUrl']?.toString() ?? ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LivingSurface(
            dark: true,
            child: _card(
              path: '/anniversaries',
              radius: 19,
              padding: 18,
              colors: const [Color(0xFF342D30), Color(0xFF211D1F)],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 89),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _text(
                            '${widget.user?.displayName ?? '我'} & ${_partner['nickName'] ?? 'TA'}',
                            size: 11,
                            color: const Color(0xFFEAA5B1),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${days ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 44,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' 天',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xB3FFFFFF),
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          _text(
                            start == null
                                ? '记住相爱的第一天'
                                : '从 ${_date(start)} 开始，认真相爱',
                            size: 11,
                            color: const Color(0x7AFFFFFF),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x29FFFFFF)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '♥',
                        style: TextStyle(
                          fontSize: 23,
                          color: Color(0xFFED8294),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_errors.isNotEmpty)
            InkWell(
              onTap: _reload,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _text(
                  '${_errors.join('、')}暂时无法读取 · 点按重试',
                  size: 11,
                  color: rose,
                ),
              ),
            ),
          for (final item in _notices)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _card(
                path: '/notifications',
                padding: 12,
                child: Row(
                  children: [
                    const Text('•', style: TextStyle(color: rose)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.title} · ${item.content}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                    const Text('›'),
                  ],
                ),
              ),
            ),
          _heading('TODAY', '今天，靠近一点', '进入问答', '/daily-question'),
          _card(
            path: '/daily-question',
            radius: 16,
            colors: const [Color(0xFFF9E3E7), Color(0xFFF5D9DF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x94FFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: _text(
                        _question?.category.isNotEmpty == true
                            ? _question!.category
                            : '每日一问',
                        size: 10,
                        color: const Color(0xFF914D5A),
                      ),
                    ),
                    const Spacer(),
                    _text(
                      _question?.bothAnswered == true
                          ? '已揭晓'
                          : _question?.myAnswer != null
                          ? '等 TA 回答'
                          : _question?.partnerAnswered == true
                          ? 'TA 已回答'
                          : '去回答',
                      size: 11,
                      color: const Color(0xFF9B6D75),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Text(
                      _question?.question ?? '留五分钟给彼此，回答今天的问题。',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF342B2E),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _answer('我', _question?.myAnswer != null),
                    Container(
                      width: 21,
                      height: 1,
                      color: const Color(0x296B444B),
                    ),
                    _answer('TA', _question?.partnerAnswered == true),
                    const Spacer(),
                    const Text(
                      '→',
                      style: TextStyle(fontSize: 19, color: Color(0xFF7F535B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _snapshot(
                  '今日心情',
                  '◌',
                  '${mine?.$1 ?? '–'} / ${theirs?.$1 ?? '–'}',
                  moodText,
                  '/mood',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _snapshot(
                  '下个纪念日',
                  '◇',
                  next == null ? '去添加' : '${next.daysFrom()} 天',
                  next?.name ?? '记住重要的日子',
                  '/anniversaries',
                  color: const Color(0xFFF1E8DB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _fitnessCard(),
          const SizedBox(height: 9),
          _energyCard(),
          _heading('MEMORIES', '最近的我们', '时间轴', '/timeline'),
          if (_moments.isEmpty)
            _card(
              path: '/moments?create=1',
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      '记录第一段共同回忆',
                      style: TextStyle(fontSize: 12, color: Color(0xFF877A7E)),
                    ),
                  ),
                  Text('＋'),
                ],
              ),
            )
          else
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _moments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, index) {
                  final item = _moments[index];
                  return SizedBox(
                    width: 130,
                    child: _card(
                      path: '/timeline',
                      padding: 6,
                      radius: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9.5),
                            child: item.images.isEmpty
                                ? Container(
                                    height: 102.5,
                                    color: const Color(0xFFF7E9EC),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '“',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 37,
                                        color: Color(0xFFD5A8AF),
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    item.images.first,
                                    width: 118,
                                    height: 102.5,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      height: 102.5,
                                      child: Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8.5, 4, 3.5),
                            child: Text(
                              item.title.isEmpty ? item.content : item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _text(_date(item.createdAt), size: 9.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          _heading('TOGETHER', '一起去做'),
          LayoutBuilder(
            builder: (_, constraints) {
              final columns = constraints.maxWidth >= 700 ? 3 : 2;
              const actions = [
                ('＋', '记录此刻', '照片与文字', '/moments?create=1', 0xFFF8DFE4),
                ('✓', '共同任务', '一起完成', '/tasks', 0xFFE4EDE5),
                ('⌁', '今天吃什么', '替选择减负', '/menu', 0xFFEFE4D5),
                ('☆', '愿望清单', '约定未来', '/wishes', 0xFFEAE4F0),
                ('□', '时光胶囊', '写给未来', '/capsules', 0xFFE1EAF0),
                ('▧', '共同相册', '收藏回忆', '/album', 0xFFF4E1D8),
              ];
              return Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final item in actions)
                    SizedBox(
                      width:
                          (constraints.maxWidth - 9 * (columns - 1)) / columns,
                      child: _card(
                        path: item.$4,
                        padding: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color(item.$5),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item.$1,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _text(item.$3, size: 10),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _fitnessCard() {
    final value = _fitness?.teamProgress ?? 0;
    final copy = value >= 85
        ? '这周节奏很稳，记得认真恢复'
        : value >= 60
        ? '共同节奏正在形成'
        : value >= 30
        ? '今天再一起完成一小步'
        : '从一次打卡开始';
    return _card(
      path: '/fitness',
      padding: 15,
      colors: const [Color(0xFF456351), Color(0xFF30483B)],
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text('↗  一起变好', size: 10, color: const Color(0xFFB8D0C0)),
                    const SizedBox(height: 7),
                    Text(
                      '本周共同完成 ${_fitness?.teamProgress ?? '—'}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3.5),
                    _text(copy, size: 9, color: const Color(0x7AFFFFFF)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${_fitness?.myStats.workouts ?? '—'}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  _text('次运动', size: 8.5, color: const Color(0x70FFFFFF)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _track(value, const Color(0xFFA7C9B2), const Color(0x1FFFFFFF)),
          const SizedBox(height: 8),
          Row(
            children: [
              _text(
                _fitness?.todayCheckin != null ? '我已打卡' : '我待打卡',
                size: 9,
                color: const Color(0xFFC3DACB),
              ),
              _text('  ·  '),
              _text(
                _fitness?.partnerCheckedIn == true ? 'TA 已打卡' : 'TA 待打卡',
                size: 9,
                color: const Color(0xFFC3DACB),
              ),
              const Spacer(),
              _text('→', color: const Color(0xFFB8D0C0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _energyCard() {
    final value = _energy ?? 0;
    final title = value >= 85
        ? '默契发光'
        : value >= 60
        ? '持续升温'
        : value >= 30
        ? '温柔生长'
        : '正在萌芽';
    final tip = value >= 85
        ? '你们正在稳定回应彼此'
        : value >= 60
        ? '爱被放进了具体行动里'
        : value >= 30
        ? '一点一滴都算数'
        : '从一次真诚互动开始';
    return _card(
      path: '/monthly-report',
      padding: 15,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text('本期恋爱能量', size: 10.5),
                    const SizedBox(height: 4),
                    Text(
                      _energy == null ? '等待相遇' : title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3.5),
                    _text('$tip · 查看关系月报', size: 10),
                  ],
                ),
              ),
              Text(
                '${_energy ?? '—'}%',
                style: const TextStyle(
                  fontSize: 26,
                  color: rose,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _track(value, rose, const Color(0xFFF1EBEC)),
        ],
      ),
    );
  }

  Widget _snapshot(
    String title,
    String symbol,
    String value,
    String note,
    String path, {
    Color? color,
  }) => _card(
    path: path,
    padding: 13,
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _text(title, size: 11, color: const Color(0xFF796E71)),
            ),
            _text(symbol, size: 14),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: muted),
        ),
      ],
    ),
  );
  Widget _heading(
    String kicker,
    String title, [
    String? action,
    String? path,
  ]) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
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
                  color: Color(0xFFA05A67),
                  fontSize: 9.5,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3.5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (action != null)
          InkWell(
            onTap: () => _open(path!),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: _text(action, size: 11.5, color: const Color(0xFF8F7F83)),
            ),
          ),
      ],
    ),
  );
  Widget _card({
    required Widget child,
    String? path,
    Color? color,
    List<Color>? colors,
    double radius = 16,
    double padding = 16,
  }) => Container(
    decoration: BoxDecoration(
      color: colors == null
          ? color ?? Theme.of(context).colorScheme.surface
          : null,
      gradient: colors == null
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Color.lerp(
          color ?? colors?.first ?? Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.outlineVariant,
          .45,
        )!,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x103C282D),
          offset: Offset(0, 5),
          blurRadius: 18,
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: path == null ? null : () => _open(path),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    ),
  );
  Widget _text(String text, {double size = 12, Color color = muted}) => Text(
    text,
    style: TextStyle(fontSize: size, color: color),
  );
  Widget _track(int percent, Color color, Color background) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percent.clamp(0, 100) / 100),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => LinearProgressIndicator(
        value: value,
        minHeight: 3.5,
        backgroundColor: background,
        color: color,
      ),
    ),
  );
  Widget _avatar(String url) => Container(
    width: 35,
    height: 35,
    padding: const EdgeInsets.all(2),
    decoration: const BoxDecoration(
      color: Color(0xFFF8F5F3),
      shape: BoxShape.circle,
    ),
    child: CircleAvatar(
      backgroundColor: const Color(0xFFEDE2D8),
      backgroundImage: const AssetImage('assets/reference/default-avatar.png'),
      foregroundImage: url.isEmpty ? null : NetworkImage(url),
    ),
  );
  Widget _answer(String text, bool done) => Container(
    width: 23,
    height: 23,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? rose : const Color(0x94FFFFFF),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 9.5,
        color: done ? Colors.white : const Color(0xFFA28D91),
      ),
    ),
  );
  static String _date(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
}

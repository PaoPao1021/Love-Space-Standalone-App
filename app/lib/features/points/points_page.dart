import 'package:flutter/material.dart';

import '../together/together_models.dart';
import '../together/together_repository.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({required this.repository, required this.userId, super.key});
  final TogetherRepository repository;
  final String userId;

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  late Future<PointScore> _score = widget.repository.score();
  late Future<PointLevel> _level = widget.repository.pointLevel();
  late Future<List<PointRecord>> _records = widget.repository.pointRecords();
  late Future<List<ExchangeOption>> _options = widget.repository
      .exchangeOptions();
  late Future<List<ExchangeRecord>> _history = widget.repository
      .exchangeHistory();
  bool _busy = false;

  void _reload() => setState(() {
    _score = widget.repository.score();
    _level = widget.repository.pointLevel();
    _records = widget.repository.pointRecords();
    _options = widget.repository.exchangeOptions();
    _history = widget.repository.exchangeHistory();
  });

  Future<void> _givePoints({int? initialAmount, String? initialReason}) async {
    final amount = TextEditingController(text: '${initialAmount ?? 10}');
    final reason = TextEditingController(text: initialReason ?? '');
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('给 TA 记积分'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: '积分变化',
                  helperText: '正数奖励，负数扣除；范围 -1000 到 1000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLength: 30,
                decoration: const InputDecoration(labelText: '原因'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final value = int.tryParse(amount.text);
      if (value == null || value == 0 || reason.text.trim().isEmpty) {
        _message('请填写有效积分和原因');
      } else {
        await _perform(
          () => widget.repository.givePoints(
            amount: value,
            reason: reason.text,
            note: note.text,
          ),
          '积分已同步给 TA',
        );
      }
    }
    amount.dispose();
    reason.dispose();
    note.dispose();
  }

  Future<void> _redeem(ExchangeOption option) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('兑换“${option.name}”？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将扣除 ${option.cost} 积分。'),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认兑换'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _perform(() => widget.repository.redeem(option, note.text), '兑换成功');
    }
    note.dispose();
  }

  Future<void> _addOption() async {
    final name = TextEditingController();
    final cost = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义兑换项目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '项目名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '所需积分'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final value = int.tryParse(cost.text);
      if (name.text.trim().isEmpty || value == null || value <= 0) {
        _message('请填写名称和有效积分');
      } else {
        await _perform(
          () => widget.repository.addExchange(name.text, value),
          '兑换项目已添加',
        );
      }
    }
    name.dispose();
    cost.dispose();
  }

  Future<void> _deleteOption(ExchangeOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除兑换项目？'),
        content: Text('“${option.name}”将不再显示，历史兑换记录仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _perform(
        () => widget.repository.deleteExchange(option.id),
        '兑换项目已删除',
      );
    }
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _reload();
      _message(success);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('甜蜜积分'),
      actions: [
        IconButton(
          tooltip: '给 TA 记积分',
          onPressed: _busy ? null : _givePoints,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([_score, _level, _options, _history]),
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
          final data = snapshot.data!;
          final options = data[2] as List<ExchangeOption>;
          final history = data[3] as List<ExchangeRecord>;
          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 104),
            children: [
              _ScoreHeader(score: data[0] as PointScore),
              _LevelBar(level: data[1] as PointLevel),
              _DashboardCard(
                title: '给TA加分',
                action: '+ 自定义',
                onAction: _givePoints,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickPoint(
                      '🌹',
                      '贴心照顾',
                      5,
                      () =>
                          _givePoints(initialAmount: 5, initialReason: '贴心照顾'),
                    ),
                    _QuickPoint(
                      '💬',
                      '好好沟通',
                      10,
                      () =>
                          _givePoints(initialAmount: 10, initialReason: '好好沟通'),
                    ),
                    _QuickPoint(
                      '🍳',
                      '做顿饭',
                      10,
                      () =>
                          _givePoints(initialAmount: 10, initialReason: '做顿饭'),
                    ),
                    _QuickPoint(
                      '🫶',
                      '主动拥抱',
                      5,
                      () =>
                          _givePoints(initialAmount: 5, initialReason: '主动拥抱'),
                    ),
                  ],
                ),
              ),
              _DashboardCard(
                title: '积分兑换',
                action: '+ 自定义',
                onAction: _addOption,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options
                      .map(
                        (item) => _ExchangeTile(
                          option: item,
                          onTap: () => _redeem(item),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (history.isNotEmpty)
                _DashboardCard(
                  title: '兑换记录',
                  action: '查看 ›',
                  onAction: () => _showHistory(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in history.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Text('🎁  ${item.itemName}    -${item.cost}分'),
                        ),
                    ],
                  ),
                ),
              ListTile(
                onTap: () => _showRecords(context),
                title: const Text(
                  '积分明细',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Text('›', style: TextStyle(fontSize: 24)),
              ),
            ],
          );
        },
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _busy ? null : _givePoints,
      backgroundColor: const Color(0xFFE85D75),
      child: const Text(
        '+',
        style: TextStyle(
          fontSize: 30,
          color: Colors.white,
          fontWeight: FontWeight.w300,
        ),
      ),
    ),
  );

  Future<void> _showRecords(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: _recordsTab(),
    ),
  );
  Future<void> _showHistory(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: _historyTab(),
    ),
  );

  Widget _recordsTab() => _AsyncList<PointRecord>(
    future: _records,
    onRetry: _reload,
    emptyText: '还没有积分记录',
    itemBuilder: (context, item) {
      final mine = item.toUser == widget.userId;
      return ListTile(
        minTileHeight: 72,
        tileColor: const Color(0xFFF7F2ED),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Text(
          item.amount >= 0 ? '✨' : '💭',
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(item.reason),
        subtitle: Text(
          '${mine ? '我的积分' : 'TA 的积分'}${item.note.isEmpty ? '' : ' · ${item.note}'}',
        ),
        trailing: Text(
          '${item.amount > 0 ? '+' : ''}${item.amount}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: item.amount >= 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ),
      );
    },
  );

  // Kept as the focused list flow for callers that need it outside the dashboard.
  // ignore: unused_element
  Widget _optionsTab() => FutureBuilder<List<ExchangeOption>>(
    future: _options,
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
      final options = snapshot.data ?? const [];
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 100),
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _addOption,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加自定义项目'),
              ),
              const SizedBox(height: 12),
              ...options.map(
                (option) => Card(
                  elevation: 0,
                  color: const Color(0xFFF7F2ED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    minTileHeight: 78,
                    leading: const Text('🎁', style: TextStyle(fontSize: 26)),
                    title: Text(option.name),
                    subtitle: Text(
                      '${option.cost} 积分${option.builtIn ? ' · 默认项目' : ' · 自定义'}',
                    ),
                    trailing: option.builtIn
                        ? const Icon(Icons.chevron_right_rounded)
                        : PopupMenuButton<String>(
                            tooltip: '兑换项目操作',
                            onSelected: (value) => value == 'redeem'
                                ? _redeem(option)
                                : _deleteOption(option),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'redeem',
                                child: Text('立即兑换'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('删除项目'),
                              ),
                            ],
                          ),
                    onTap: _busy ? null : () => _redeem(option),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _historyTab() => _AsyncList<ExchangeRecord>(
    future: _history,
    onRetry: _reload,
    emptyText: '还没有兑换记录',
    itemBuilder: (context, item) => ListTile(
      minTileHeight: 72,
      leading: const CircleAvatar(child: Icon(Icons.redeem_outlined)),
      title: Text(item.itemName),
      subtitle: Text(item.userId == widget.userId ? '由我兑换' : '由 TA 兑换'),
      trailing: Text(
        '-${item.cost}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});
  final PointLevel? level;

  @override
  Widget build(BuildContext context) {
    final value = level;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '距离「${value?.nextName.isNotEmpty == true ? value!.nextName : '下一等级'}」还需 ${value == null ? '—' : (value.nextMinimum - value.score).clamp(0, 999999)} 积分',
                style: const TextStyle(color: Color(0xFFA79DA0), fontSize: 12),
              ),
              if (value != null && value.nextName.isNotEmpty)
                Text('下一等级：${value.nextName}'),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: value?.progress ?? 0),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.action,
    required this.onAction,
    required this.child,
  });
  final String title, action;
  final VoidCallback onAction;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onAction, child: Text(action)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}

class _QuickPoint extends StatelessWidget {
  const _QuickPoint(this.emoji, this.label, this.points, this.onTap);
  final String emoji, label;
  final int points;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 66,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 23)),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
          Text(
            '+$points',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA05A67),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ExchangeTile extends StatelessWidget {
  const _ExchangeTile({required this.option, required this.onTap});
  final ExchangeOption option;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 23)),
          const SizedBox(height: 3),
          Text(
            option.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
          Text(
            '${option.cost}分',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA05A67),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.score});
  final PointScore? score;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECA8B4), Color(0xFFF6DDE2), Color(0xFFD4C5B0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .93),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ScoreCard(label: '我的积分', value: score?.mine),
            ),
            const Text('💕', style: TextStyle(fontSize: 24)),
            Expanded(
              child: _ScoreCard(label: 'TA的积分', value: score?.partner),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.label, required this.value});
  final String label;
  final int? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(
          value?.toString() ?? '—',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFECA8B4),
          ),
        ),
      ],
    ),
  );
}

class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({
    required this.future,
    required this.onRetry,
    required this.emptyText,
    required this.itemBuilder,
  });
  final Future<List<T>> future;
  final VoidCallback onRetry;
  final String emptyText;
  final Widget Function(BuildContext, T) itemBuilder;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('加载失败，点按重试'),
          ),
        );
      }
      final items = snapshot.data ?? const [];
      if (items.isEmpty) return Center(child: Text(emptyText));
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => itemBuilder(context, items[index]),
          ),
        ),
      );
    },
  );
}

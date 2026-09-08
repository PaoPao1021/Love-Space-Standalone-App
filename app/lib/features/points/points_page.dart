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

class _PointsPageState extends State<PointsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
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

  Future<void> _givePoints() async {
    final amount = TextEditingController(text: '10');
    final reason = TextEditingController();
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
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        tabs: const [
          Tab(text: '积分记录'),
          Tab(text: '兑换中心'),
          Tab(text: '兑换历史'),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          FutureBuilder<PointScore>(
            future: _score,
            builder: (context, snapshot) => _ScoreHeader(score: snapshot.data),
          ),
          FutureBuilder<PointLevel>(
            future: _level,
            builder: (context, snapshot) => _LevelBar(level: snapshot.data),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_recordsTab(), _optionsTab(), _historyTab()],
            ),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : _givePoints,
      icon: const Icon(Icons.stars_outlined),
      label: const Text('记积分'),
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
        leading: CircleAvatar(
          child: Icon(
            item.amount >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _addOption,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加自定义项目'),
              ),
              const SizedBox(height: 12),
              ...options.map(
                (option) => Card(
                  child: ListTile(
                    minTileHeight: 78,
                    leading: const CircleAvatar(
                      child: Icon(Icons.card_giftcard_outlined),
                    ),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(value?.name ?? '正在计算甜蜜等级…')),
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

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.score});
  final PointScore? score;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: _ScoreCard(label: '我的积分', value: score?.mine),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreCard(label: 'TA 的积分', value: score?.partner),
        ),
      ],
    ),
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.label, required this.value});
  final String label;
  final int? value;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            value?.toString() ?? '—',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
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

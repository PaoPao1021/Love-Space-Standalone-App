import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({required this.repository, super.key});
  final CoreLoopRepository repository;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final List<MomentEntry> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.moments(page: _page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _more = result.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _random() async {
    try {
      final item = await widget.repository.randomMoment();
      if (!mounted) return;
      if (item == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('还没有可以回看的点滴')));
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.title.isEmpty ? _date(item.createdAt) : item.title),
          content: Text(item.content.isEmpty ? '一张值得记住的照片' : item.content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('收好'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Map<String, List<MomentEntry>> _groups() {
    final result = <String, List<MomentEntry>>{};
    for (final item in _items) {
      final date = item.eventDate ?? item.createdAt;
      final key = '${date.year} 年 ${date.month} 月';
      result.putIfAbsent(key, () => []).add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('我们的时间轴'),
      actions: [
        IconButton(
          tooltip: '随机回忆',
          onPressed: _random,
          icon: const Icon(Icons.shuffle_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/moments'),
      icon: const Icon(Icons.add_rounded),
      label: const Text('记录此刻'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _error != null && _items.isEmpty
              ? Center(
                  child: OutlinedButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('加载失败，点按重试'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      if (_items.isEmpty && !_loading)
                        const Padding(
                          padding: EdgeInsets.all(36),
                          child: Column(
                            children: [
                              Icon(Icons.timeline_rounded, size: 56),
                              SizedBox(height: 14),
                              Text('第一段共同回忆，等你们写下'),
                            ],
                          ),
                        )
                      else
                        ..._groups().entries.expand(
                          (group) => [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                              child: Text(
                                group.key,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            ...group.value.map(
                              (item) => _TimelineCard(item: item),
                            ),
                          ],
                        ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(22),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_more)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton(
                            onPressed: () {
                              _page += 1;
                              _load(reset: false);
                            },
                            child: const Text('加载更早的回忆'),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.item});
  final MomentEntry item;

  @override
  Widget build(BuildContext context) {
    final date = item.eventDate ?? item.createdAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('${date.month}月'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.title.isNotEmpty)
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (item.content.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          item.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

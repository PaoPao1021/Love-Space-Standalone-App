import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.repository, super.key});
  final CoreLoopRepository repository;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<({List<AppNotification> items, int unread})> _data = widget
      .repository
      .notifications();

  void _reload() => setState(() => _data = widget.repository.notifications());

  Future<void> _readAll() async {
    await widget.repository.readAll();
    _reload();
  }

  Future<void> _open(AppNotification item) async {
    if (!item.read) await widget.repository.markRead(item.id);
    if (!mounted) return;
    final path = switch (item.type) {
      'daily-question' => '/daily-question',
      'moment' =>
        item.relatedId.isEmpty ? '/moments' : '/moments/${item.relatedId}',
      'mood' => '/mood',
      'photo' => item.relatedId.isEmpty ? '/album' : '/album/${item.relatedId}',
      'anniversary' => '/anniversaries',
      'task' || 'task_complete' =>
        item.relatedId.isEmpty ? '/tasks' : '/tasks/${item.relatedId}',
      'menu_order' => '/menu',
      'points' => '/points',
      'wish' =>
        item.relatedId.isEmpty ? '/wishes' : '/wishes/${item.relatedId}',
      'capsule' || 'capsule_unlocked' =>
        item.relatedId.isEmpty ? '/capsules' : '/capsules/${item.relatedId}',
      'fitness' => '/fitness',
      'quiz' => '/quiz',
      _ => '/notifications',
    };
    if (path != '/notifications') await context.push(path);
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('通知中心'),
      actions: [TextButton(onPressed: _readAll, child: const Text('全部已读'))],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<({List<AppNotification> items, int unread})>(
            future: _data,
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
              final items = snapshot.data?.items ?? const [];
              if (items.isEmpty) return const _EmptyNotifications();
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _data;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        minTileHeight: 78,
                        leading: CircleAvatar(
                          backgroundColor: item.read
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(_icon(item.type)),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.w800,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            item.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: item.read
                            ? const Icon(Icons.chevron_right_rounded)
                            : Semantics(
                                label: '未读',
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                        onTap: () => _open(item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  static IconData _icon(String type) => switch (type) {
    'daily-question' => Icons.forum_outlined,
    'moment' => Icons.auto_awesome_outlined,
    'mood' => Icons.mood_outlined,
    'photo' => Icons.photo_outlined,
    'anniversary' => Icons.event_outlined,
    'task' || 'task_complete' => Icons.task_alt_outlined,
    'menu_order' => Icons.restaurant_menu_outlined,
    'points' => Icons.stars_outlined,
    'wish' => Icons.favorite_border_rounded,
    'capsule' || 'capsule_unlocked' => Icons.lock_clock_outlined,
    'fitness' => Icons.directions_run_outlined,
    'quiz' => Icons.psychology_alt_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 54),
          SizedBox(height: 16),
          Text('暂时没有通知'),
        ],
      ),
    ),
  );
}

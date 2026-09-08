import 'package:flutter/material.dart';

import '../together/together_models.dart';
import '../together/together_repository.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    required this.repository,
    required this.userId,
    this.targetTaskId,
    super.key,
  });
  final TogetherRepository repository;
  final String userId;
  final String? targetTaskId;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String _status = 'pending';
  bool _busy = false;
  late Future<List<CoupleTask>> _tasks = _load();

  Future<List<CoupleTask>> _load() async {
    final items = [...await widget.repository.tasks(status: _status)];
    final targetId = widget.targetTaskId;
    if (targetId == null || targetId.isEmpty) return items;
    final index = items.indexWhere((item) => item.id == targetId);
    if (index > 0) items.insert(0, items.removeAt(index));
    if (index < 0) {
      try {
        items.insert(0, await widget.repository.task(targetId));
      } catch (_) {}
    }
    return items;
  }

  void _reload() => setState(() => _tasks = _load());

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TaskEditor(repository: widget.repository),
    );
    if (created == true) {
      _status = 'pending';
      _reload();
    }
  }

  Future<void> _complete(CoupleTask task) async {
    await _perform(() => widget.repository.completeTask(task.id), '任务已完成');
  }

  Future<void> _delete(CoupleTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务？'),
        content: Text('“${task.title}”删除后无法恢复。'),
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
      await _perform(() => widget.repository.deleteTask(task.id), '任务已删除');
    }
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('共同任务'),
      actions: [
        IconButton(
          tooltip: '新建任务',
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.add_task_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'pending', label: Text('待完成')),
                      ButtonSegment(value: 'completed', label: Text('已完成')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (value) {
                      _status = value.first;
                      _reload();
                    },
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CoupleTask>>(
                  future: _tasks,
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
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return _TaskEmpty(completed: _status == 'completed');
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _tasks;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TaskCard(
                              task: item,
                              userId: widget.userId,
                              highlighted: item.id == widget.targetTaskId,
                              busy: _busy,
                              onComplete: () => _complete(item),
                              onDelete: () => _delete(item),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : _create,
      icon: const Icon(Icons.add_rounded),
      label: const Text('新建任务'),
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.userId,
    required this.highlighted,
    required this.busy,
    required this.onComplete,
    required this.onDelete,
  });
  final CoupleTask task;
  final String userId;
  final bool highlighted;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final mine = task.createdBy == userId;
    final due = task.dueDate;
    final overdue =
        due != null &&
        !task.completed &&
        due.isBefore(DateUtils.dateOnly(DateTime.now()));
    return Card(
      color: highlighted
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.45)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  task.completed
                      ? Icons.task_alt_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (mine)
                  IconButton(
                    tooltip: '删除任务',
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.description),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(_assignee(task.assignee)),
                ),
                if (task.rewardPoints > 0)
                  Chip(
                    avatar: const Icon(Icons.stars_outlined, size: 18),
                    label: Text('${task.rewardPoints} 积分'),
                  ),
                if (due != null)
                  Chip(
                    avatar: Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.event_outlined,
                      size: 18,
                    ),
                    label: Text('${overdue ? '已逾期 · ' : ''}${_date(due)}'),
                  ),
              ],
            ),
            if (task.canComplete(userId)) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : onComplete,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('标记完成'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _assignee(String value) => switch (value) {
    'me' => '创建者完成',
    'partner' => '对方完成',
    _ => '两人都可以',
  };
  static String _date(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.repository});
  final TogetherRepository repository;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  final String _requestId = TogetherRepository.requestId('task');
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _assignee = 'both';
  double _reward = 10;
  DateTime? _dueDate;
  bool _saving = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createTask(
        requestId: _requestId,
        title: _title.text,
        description: _description.text,
        assignee: _assignee,
        reward: _reward.round(),
        dueDate: _dueDate,
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
    _title.dispose();
    _description.dispose();
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
          Text('新建任务', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            maxLength: 50,
            autofocus: true,
            decoration: const InputDecoration(labelText: '任务标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '说明（可选）'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _assignee,
            decoration: const InputDecoration(labelText: '由谁完成'),
            items: const [
              DropdownMenuItem(value: 'both', child: Text('两个人都可以')),
              DropdownMenuItem(value: 'me', child: Text('我来完成')),
              DropdownMenuItem(value: 'partner', child: Text('交给 TA')),
            ],
            onChanged: (value) => _assignee = value ?? 'both',
          ),
          const SizedBox(height: 16),
          Text('完成奖励：${_reward.round()} 积分'),
          Slider(
            value: _reward,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_reward.round()}',
            onChanged: (value) => setState(() => _reward = value),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: _dueDate ?? DateTime.now(),
              );
              if (selected != null && mounted) {
                setState(() => _dueDate = selected);
              }
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _dueDate == null
                  ? '设置截止日期（可选）'
                  : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在创建…' : '创建任务'),
          ),
        ],
      ),
    ),
  );
}

class _TaskEmpty extends StatelessWidget {
  const _TaskEmpty({required this.completed});
  final bool completed;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.inbox_outlined : Icons.task_alt_outlined,
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(completed ? '还没有已完成任务' : '现在没有待办，一身轻松'),
        ],
      ),
    ),
  );
}

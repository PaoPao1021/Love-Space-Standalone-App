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
  bool _busy = false;
  late Future<List<CoupleTask>> _tasks = _load();

  Future<List<CoupleTask>> _load() async {
    final groups = await Future.wait([
      widget.repository.tasks(status: 'pending'),
      widget.repository.tasks(status: 'completed'),
    ]);
    final items = [...groups[0], ...groups[1]]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    appBar: AppBar(title: const Text('共同任务')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
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
                    if (items.isEmpty) return const _TaskEmpty();
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _tasks;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(28, 10, 28, 112),
                        itemCount: items.length + 1,
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '${items.length}个任务',
                                style: const TextStyle(
                                  color: Color(0xFFA79DA0),
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }
                          final item = items[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TaskCard(
                              task: item,
                              userId: widget.userId,
                              highlighted: item.id == widget.targetTaskId,
                              busy: _busy,
                              onComplete: () => _complete(item),
                              onDelete: () => _delete(item),
                              onTap: () => _showDetail(item),
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
    floatingActionButton: FloatingActionButton(
      onPressed: _busy ? null : _create,
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

  Future<void> _showDetail(CoupleTask task) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _TaskDetail(
      task: task,
      userId: widget.userId,
      busy: _busy,
      onComplete: () {
        Navigator.pop(context);
        _complete(task);
      },
      onDelete: () {
        Navigator.pop(context);
        _delete(task);
      },
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
    required this.onTap,
  });
  final CoupleTask task;
  final String userId;
  final bool highlighted;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate;
    final overdue =
        due != null &&
        !task.completed &&
        due.isBefore(DateUtils.dateOnly(DateTime.now()));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        color: highlighted
            ? const Color(0xFFF9E7EA)
            : task.completed
            ? const Color(0xFFF8F5F2)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.completed ? '✅' : '⬜',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
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
                  _softTag(_assignee(task.assignee), const Color(0xFFF8EDED)),
                  if (task.rewardPoints > 0)
                    Text(
                      '+${task.rewardPoints}积分',
                      style: const TextStyle(
                        color: Color(0xFFA05A67),
                        fontWeight: FontWeight.w600,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  static String _assignee(String value) => switch (value) {
    'me' => '我的',
    'partner' => 'TA的',
    _ => '双方',
  };
  static Widget _softTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, color: Color(0xFFA05A67)),
    ),
  );
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

class _TaskDetail extends StatelessWidget {
  const _TaskDetail({
    required this.task,
    required this.userId,
    required this.busy,
    required this.onComplete,
    required this.onDelete,
  });
  final CoupleTask task;
  final String userId;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: task.completed
                ? const Color(0xFFEEF2EB)
                : const Color(0xFFF7F2ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            task.completed ? '✅ 已完成' : '⏳ 进行中',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          task.title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(task.description),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          children: [
            _info('积分奖励', '+${task.rewardPoints}'),
            _info('指派给', _TaskCard._assignee(task.assignee)),
            _info('创建时间', _TaskCard._date(task.createdAt)),
            if (task.completedBy.isNotEmpty) _info('完成者', task.completedBy),
          ],
        ),
        if (task.canComplete(userId)) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE85D75),
              shape: const StadiumBorder(),
            ),
            child: Text('标记完成 +${task.rewardPoints}积分'),
          ),
        ],
        if (task.createdBy == userId)
          TextButton(
            onPressed: busy ? null : onDelete,
            child: const Text('删除任务'),
          ),
      ],
    ),
  );
  static Widget _info(String label, String value) => SizedBox(
    width: 150,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFA79DA0), fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _TaskEmpty extends StatelessWidget {
  const _TaskEmpty();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          const Text('还没有任务'),
          const SizedBox(height: 8),
          const Text('给对方指派任务，完成后获得积分~'),
        ],
      ),
    ),
  );
}

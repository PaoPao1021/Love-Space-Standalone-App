import 'package:flutter/material.dart';

import 'anniversary.dart';
import 'anniversary_repository.dart';

class AnniversaryPage extends StatefulWidget {
  const AnniversaryPage({required this.repository, super.key});

  final AnniversaryRepository repository;

  @override
  State<AnniversaryPage> createState() => _AnniversaryPageState();
}

class _AnniversaryPageState extends State<AnniversaryPage> {
  late Future<List<Anniversary>> _items = widget.repository.list();

  void _reload() {
    setState(() => _items = widget.repository.list());
  }

  Future<void> _showAddSheet([Anniversary? existing]) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _AnniversaryForm(repository: widget.repository, existing: existing),
    );
    if (added == true && mounted) {
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('纪念日已保存')));
    }
  }

  Future<void> _delete(Anniversary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除纪念日？'),
        content: Text('“${item.name}”删除后无法恢复。'),
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
    if (confirmed != true) return;
    try {
      await widget.repository.delete(item.id);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showDetail(Anniversary item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final days = item.daysFrom();
        final count = days == 0 ? '就是今天' : days > 0 ? '$days 天后' : '${days.abs()} 天前';
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_AnniversaryCard._emojiFor(item.type), style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            Text(item.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(_AnniversaryCard._formatDate(item.date), style: const TextStyle(color: Color(0xFF948A8D))),
            const SizedBox(height: 18),
            Text(count, style: const TextStyle(color: Color(0xFFA05A67), fontSize: 28, fontWeight: FontWeight.w800)),
            if (item.note.isNotEmpty) ...[const SizedBox(height: 14), Text(item.note, textAlign: TextAlign.center)],
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('删除'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, 'edit'), child: const Text('编辑纪念日'))),
            ]),
          ]),
        ));
      },
    );
    if (!mounted) return;
    if (action == 'edit') await _showAddSheet(item);
    if (action == 'delete') await _delete(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F3),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: const Color(0xFFE85D75),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Text('+', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300)),
      ),
      body: FutureBuilder<List<Anniversary>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              title: '没有读到纪念日',
              message: '请检查网络后重试。',
              actionLabel: '重新加载',
              onAction: _reload,
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _MessageState(
              icon: Icons.calendar_month_outlined,
              title: '还没有纪念日',
              message: '从一个对你们重要的日期开始。',
              actionLabel: '添加第一个纪念日',
              onAction: _showAddSheet,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _items;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 104),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _AnniversaryCard(
                item: items[index],
                onEdit: () => _showDetail(items[index]),
                onDelete: () => _delete(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnniversaryCard extends StatelessWidget {
  const _AnniversaryCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Anniversary item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = item.daysFrom();
    final label = days == 0
        ? '今天'
        : days > 0
        ? '$days 天后'
        : '${days.abs()} 天前';
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: item.isTop ? const Border(left: BorderSide(color: Color(0xFFECA8B4), width: 3)) : null,
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF7F2ED), Color(0xFFF0E8DE)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(_emojiFor(item.type), style: const TextStyle(fontSize: 25))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(color: Color(0xFF2D2729),
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    if (item.isTop) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.push_pin_rounded,
                        size: 17,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: '已置顶',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDate(item.date),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: '距离${item.name}$label',
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFA05A67), fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          PopupMenuButton<String>(
            tooltip: '纪念日操作',
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    ));
  }

  static String _emojiFor(String type) => switch (type) {
    'together' => '💕', 'birthday' => '🎂', 'valentine' => '❤️', 'meet' => '🤝', _ => '📅',
  };

  static String _formatDate(DateTime value) {
    return '${value.year} 年 ${value.month} 月 ${value.day} 日';
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnniversaryForm extends StatefulWidget {
  const _AnniversaryForm({required this.repository, this.existing});

  final AnniversaryRepository repository;
  final Anniversary? existing;

  @override
  State<_AnniversaryForm> createState() => _AnniversaryFormState();
}

class _AnniversaryFormState extends State<_AnniversaryForm> {
  static const _types = {
    'together': '在一起',
    'birthday': '生日',
    'valentine': '情人节',
    'meet': '见面',
    'custom': '自定义',
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String _type = 'custom';
  bool _repeat = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _nameController.text = item.name;
      _noteController.text = item.note;
      _date = item.date;
      _type = item.type;
      _repeat = item.isRepeat;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: '选择纪念日日期',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = AnniversaryDraft(
        name: _nameController.text,
        date: _date,
        type: _type,
        note: _noteController.text,
        isRepeat: _repeat,
      );
      if (widget.existing == null) {
        await widget.repository.add(draft);
      } else {
        await widget.repository.update(widget.existing!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '保存失败，请检查网络后重试');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? '添加纪念日' : '编辑纪念日',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                maxLength: 30,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：在一起纪念日',
                  prefixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '请输入纪念日名称';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_AnniversaryCard._formatDate(_date)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 20),
              Text('类型', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) => setState(() => _type = entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _noteController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注（选填）',
                  hintText: '写下一点属于你们的细节',
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每年提醒'),
                subtitle: const Text('按这个月日计算下一次纪念日'),
                value: _repeat,
                onChanged: (value) => setState(() => _repeat = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.existing == null ? '保存纪念日' : '保存修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

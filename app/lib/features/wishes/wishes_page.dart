import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/storage/account_cache.dart';
import '../memories/memories_models.dart';
import '../memories/memories_repository.dart';

class WishesPage extends StatefulWidget {
  const WishesPage({
    required this.repository,
    required this.cache,
    this.targetWishId,
    super.key,
  });

  final MemoriesRepository repository;
  final AccountCache cache;
  final String? targetWishId;

  @override
  State<WishesPage> createState() => _WishesPageState();
}

class _WishesPageState extends State<WishesPage> {
  String _status = 'todo';
  bool _busy = false;
  late Future<List<WishEntry>> _wishes = _load();

  Future<List<WishEntry>> _load() async {
    final items = [...await widget.repository.wishes()];
    final target = widget.targetWishId;
    if (target != null && target.isNotEmpty) {
      WishEntry? found;
      for (final item in items) {
        if (item.id == target) {
          found = item;
          break;
        }
      }
      if (found != null) _status = found.status;
      items.sort((a, b) {
        if (a.id == target) return -1;
        if (b.id == target) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return items;
  }

  void _reload() => setState(() => _wishes = _load());

  Future<void> _edit([WishEntry? item]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WishEditor(
        repository: widget.repository,
        cache: widget.cache,
        existing: item,
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _setStatus(WishEntry item, String status) =>
      _perform(() => widget.repository.updateWish(item.id, status: status));

  Future<void> _delete(WishEntry item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除愿望？'),
        content: Text('“${item.title}”删除后无法恢复。'),
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
      await _perform(() => widget.repository.deleteWish(item.id));
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _reload();
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
      title: const Text('我们的愿望'),
      actions: [
        IconButton(
          tooltip: '写下愿望',
          onPressed: _busy ? null : _edit,
          icon: const Icon(Icons.add_rounded),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'todo', label: Text('想一起做')),
                      ButtonSegment(value: 'doing', label: Text('进行中')),
                      ButtonSegment(value: 'done', label: Text('已实现')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (value) =>
                        setState(() => _status = value.first),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<WishEntry>>(
                  future: _wishes,
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
                    final items = (snapshot.data ?? const [])
                        .where((item) => item.status == _status)
                        .toList(growable: false);
                    if (items.isEmpty) {
                      return _WishEmpty(status: _status, onCreate: _edit);
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _wishes;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _WishCard(
                            item: item,
                            highlighted: item.id == widget.targetWishId,
                            busy: _busy,
                            onEdit: () => _edit(item),
                            onDelete: () => _delete(item),
                            onStatus: (status) => _setStatus(item, status),
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
      onPressed: _busy ? null : _edit,
      icon: const Icon(Icons.favorite_border_rounded),
      label: const Text('写下愿望'),
    ),
  );
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.item,
    required this.highlighted,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });

  final WishEntry item;
  final bool highlighted;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => Card(
    color: highlighted
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.imageUrl.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    enabled: !busy,
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.description),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: busy
                      ? null
                      : () => onStatus(switch (item.status) {
                          'todo' => 'doing',
                          'doing' => 'done',
                          _ => 'todo',
                        }),
                  icon: Icon(switch (item.status) {
                    'todo' => Icons.play_arrow_rounded,
                    'doing' => Icons.done_all_rounded,
                    _ => Icons.replay_rounded,
                  }),
                  label: Text(switch (item.status) {
                    'todo' => '开始行动',
                    'doing' => '标记为已实现',
                    _ => '重新放回愿望单',
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WishEditor extends StatefulWidget {
  const _WishEditor({
    required this.repository,
    required this.cache,
    this.existing,
  });
  final MemoriesRepository repository;
  final AccountCache cache;
  final WishEntry? existing;

  @override
  State<_WishEditor> createState() => _WishEditorState();
}

class _WishEditorState extends State<_WishEditor> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  XFile? _image;
  bool _saving = false;
  String _requestId = '';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final item = widget.existing;
    if (item != null) {
      _title.text = item.title;
      _description.text = item.description;
      return;
    }
    _title.text = await widget.cache.readText('wish.title.draft');
    _description.text = await widget.cache.readText('wish.description.draft');
    _requestId = await widget.cache.readText('wish.request.draft');
    if (_requestId.isEmpty) {
      _requestId = MemoriesRepository.requestId('wish');
      await widget.cache.writeText('wish.request.draft', _requestId);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.cache.writeText('wish.title.draft', _title.text);
        await widget.cache.writeText(
          'wish.description.draft',
          _description.text,
        );
        MemoryUploadImage? image;
        if (_image != null) {
          image = MemoryUploadImage(
            bytes: await _image!.readAsBytes(),
            fileName: _image!.name,
          );
        }
        await widget.repository.createWish(
          requestId: _requestId,
          title: _title.text,
          description: _description.text,
          image: image,
        );
        for (final key in [
          'wish.title.draft',
          'wish.description.draft',
          'wish.request.draft',
        ]) {
          await widget.cache.writeText(key, '');
        }
      } else {
        await widget.repository.updateWish(
          existing.id,
          title: _title.text,
          description: _description.text,
        );
      }
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
          Text(
            widget.existing == null ? '写下一个愿望' : '编辑愿望',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: '愿望标题'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 7,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: '想和 TA 一起怎样实现？'),
          ),
          if (widget.existing == null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null && mounted) {
                        setState(() => _image = picked);
                      }
                    },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_image == null ? '添加一张期待的照片（可选）' : '已选择照片，点按更换'),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存'),
          ),
        ],
      ),
    ),
  );
}

class _WishEmpty extends StatelessWidget {
  const _WishEmpty({required this.status, required this.onCreate});
  final String status;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border_rounded, size: 56),
          const SizedBox(height: 14),
          Text(switch (status) {
            'doing' => '还没有正在实现的愿望',
            'done' => '第一个实现的愿望正在路上',
            _ => '一起写下想去的地方、想做的小事',
          }),
          if (status == 'todo') ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onCreate, child: const Text('写下愿望')),
          ],
        ],
      ),
    ),
  );
}

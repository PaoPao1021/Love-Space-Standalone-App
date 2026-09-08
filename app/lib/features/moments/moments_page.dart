import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/storage/account_cache.dart';
import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({
    required this.repository,
    required this.cache,
    this.targetMomentId,
    super.key,
  });
  final CoreLoopRepository repository;
  final AccountCache cache;
  final String? targetMomentId;
  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final _scroll = ScrollController();
  final List<MomentEntry> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _fromCache = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 280 && _hasMore && !_loadingMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _loading = true;
      _error = null;
    } else {
      _loadingMore = true;
    }
    if (mounted) setState(() {});
    try {
      final result = await widget.repository.moments(page: _page);
      if (reset) _items.clear();
      _items.addAll(result.items);
      final targetId = widget.targetMomentId;
      if (reset && targetId != null && targetId.isNotEmpty) {
        final existingIndex = _items.indexWhere((item) => item.id == targetId);
        if (existingIndex > 0) {
          _items.insert(0, _items.removeAt(existingIndex));
        } else if (existingIndex < 0) {
          _items.insert(0, await widget.repository.moment(targetId));
        }
      }
      _fromCache = result.fromCache;
      _hasMore = result.hasMore;
      if (_hasMore) _page++;
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _compose([MomentEntry? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MomentEditor(
        repository: widget.repository,
        cache: widget.cache,
        existing: existing,
      ),
    );
    if (saved == true) _load(reset: true);
  }

  Future<void> _delete(MomentEntry item) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除这条点滴？'),
            content: const Text('删除后无法恢复。'),
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
        ) ??
        false;
    if (!confirmed) return;
    await widget.repository.deleteMoment(item.id);
    if (mounted) {
      setState(() => _items.removeWhere((value) => value.id == item.id));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('点点滴滴'),
      actions: [
        IconButton(
          tooltip: '发布点滴',
          onPressed: _compose,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _body(context),
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _compose,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('记录此刻'),
    ),
  );

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: OutlinedButton(
          onPressed: () => _load(reset: true),
          child: const Text('加载失败，点按重试'),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 58),
              SizedBox(height: 16),
              Text('第一条点滴，等你们一起写下'),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount:
            _items.length + (_loadingMore ? 1 : 0) + (_fromCache ? 1 : 0),
        itemBuilder: (context, index) {
          if (_fromCache && index == 0) {
            return const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('当前展示最近缓存'),
                subtitle: Text('网络恢复后下拉即可刷新'),
              ),
            );
          }
          final itemIndex = index - (_fromCache ? 1 : 0);
          if (itemIndex >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[itemIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MomentCard(
              item: item,
              highlighted: item.id == widget.targetMomentId,
              onEdit: () => _compose(item),
              onDelete: () => _delete(item),
            ),
          );
        },
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.item,
    required this.highlighted,
    required this.onEdit,
    required this.onDelete,
  });
  final MomentEntry item;
  final bool highlighted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
    color: highlighted
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45)
        : null,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (highlighted) ...[
                Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  item.title.isEmpty ? '生活片段' : item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          if (item.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.content),
          ],
          if (item.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: item.images.length,
              itemBuilder: (_, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ],
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _date(item.eventDate ?? item.createdAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
  static String _date(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
}

class _MomentEditor extends StatefulWidget {
  const _MomentEditor({
    required this.repository,
    required this.cache,
    this.existing,
  });
  final CoreLoopRepository repository;
  final AccountCache cache;
  final MomentEntry? existing;
  @override
  State<_MomentEditor> createState() => _MomentEditorState();
}

class _MomentEditorState extends State<_MomentEditor> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();
  final List<XFile> _images = [];
  DateTime _date = DateTime.now();
  bool _saving = false;
  String _requestId = CoreLoopRepository.newRequestId('moment');

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final item = widget.existing;
    if (item != null) {
      _title.text = item.title;
      _content.text = item.content;
      _tags.text = item.tags.join(' ');
      _date = item.eventDate ?? item.createdAt;
      _requestId = '';
    } else {
      _title.text = await widget.cache.readText('moment.title.draft');
      _content.text = await widget.cache.readText('moment.content.draft');
      _tags.text = await widget.cache.readText('moment.tags.draft');
      _requestId = await widget.cache.readText('moment.request.draft');
      if (_requestId.isEmpty) {
        _requestId = CoreLoopRepository.newRequestId('moment');
        await widget.cache.writeText('moment.request.draft', _requestId);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      limit: 9 - _images.length,
    );
    if (mounted) {
      setState(() => _images.addAll(picked.take(9 - _images.length)));
    }
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty &&
        _images.isEmpty &&
        (widget.existing?.images.isEmpty ?? true)) {
      return;
    }
    setState(() => _saving = true);
    if (widget.existing == null) {
      await widget.cache.writeText('moment.title.draft', _title.text);
      await widget.cache.writeText('moment.content.draft', _content.text);
      await widget.cache.writeText('moment.tags.draft', _tags.text);
    }
    try {
      final tags = _tags.text
          .split(RegExp(r'[\s,，]+'))
          .where((value) => value.isNotEmpty)
          .take(10)
          .toList();
      if (widget.existing != null) {
        await widget.repository.updateMoment(
          widget.existing!,
          title: _title.text,
          content: _content.text,
          tags: tags,
        );
      } else {
        final images = <UploadImage>[];
        for (final image in _images) {
          images.add(
            UploadImage(bytes: await image.readAsBytes(), fileName: image.name),
          );
        }
        await widget.repository.publishMoment(
          requestId: _requestId,
          title: _title.text,
          content: _content.text,
          date: _date,
          tags: tags,
          images: images,
        );
        for (final key in [
          'moment.title.draft',
          'moment.content.draft',
          'moment.tags.draft',
          'moment.request.draft',
        ]) {
          await widget.cache.writeText(key, '');
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发布失败，文字草稿已保留：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.existing == null ? '记录此刻' : '编辑点滴',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            maxLength: 50,
            decoration: const InputDecoration(labelText: '标题（可选）'),
            onChanged: widget.existing == null
                ? (value) => widget.cache.writeText('moment.title.draft', value)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            maxLength: 5000,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '发生了什么？'),
            onChanged: widget.existing == null
                ? (value) =>
                      widget.cache.writeText('moment.content.draft', value)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: '标签',
              hintText: '旅行 日常 美食',
            ),
            onChanged: widget.existing == null
                ? (value) => widget.cache.writeText('moment.tags.draft', value)
                : null,
          ),
          if (widget.existing == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _images.length >= 9 ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text('添加照片 ${_images.length}/9'),
            ),
            if (_images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '已选择 ${_images.length} 张；若发布失败，请重新选择图片。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                initialDate: _date,
              );
              if (selected != null && mounted) setState(() => _date = selected);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    ),
  );
}

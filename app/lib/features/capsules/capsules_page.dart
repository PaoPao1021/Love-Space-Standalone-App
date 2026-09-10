import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/storage/account_cache.dart';
import '../memories/memories_models.dart';
import '../memories/memories_repository.dart';

class CapsulesPage extends StatefulWidget {
  const CapsulesPage({
    required this.repository,
    required this.cache,
    this.targetCapsuleId,
    super.key,
  });

  final MemoriesRepository repository;
  final AccountCache cache;
  final String? targetCapsuleId;

  @override
  State<CapsulesPage> createState() => _CapsulesPageState();
}

class _CapsulesPageState extends State<CapsulesPage> {
  late Future<CapsuleList> _capsules = _load();

  Future<CapsuleList> _load() async {
    final result = await widget.repository.capsules();
    return result;
  }

  void _reload() => setState(() => _capsules = _load());

  Future<void> _create() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _CapsuleEditor(repository: widget.repository, cache: widget.cache),
    );
    if (changed == true) {
      _reload();
    }
  }

  Future<void> _open(TimeCapsule item) async {
    TimeCapsule current = item;
    try {
      current = await widget.repository.capsule(item.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CapsuleDetail(item: current),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('时光胶囊'),
      actions: [
        IconButton(
          tooltip: '写一封胶囊',
          onPressed: _create,
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
              Expanded(
                child: FutureBuilder<CapsuleList>(
                  future: _capsules,
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
                    final result =
                        snapshot.data ??
                        const CapsuleList(locked: [], unlocked: []);
                    if (result.locked.isEmpty && result.unlocked.isEmpty) {
                      return _CapsuleEmpty(locked: true, onCreate: _create);
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _capsules;
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                        children: [
                          if (result.locked.isNotEmpty) ...[
                            const _CapsuleSectionTitle('🔒 等待开启'),
                            const SizedBox(height: 10),
                            ...result.locked.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CapsuleCard(
                                  item: item,
                                  highlighted:
                                      item.id == widget.targetCapsuleId,
                                  onTap: () {},
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (result.unlocked.isNotEmpty) ...[
                            const _CapsuleSectionTitle('📬 已开启'),
                            const SizedBox(height: 10),
                            ...result.unlocked.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CapsuleCard(
                                  item: item,
                                  highlighted:
                                      item.id == widget.targetCapsuleId,
                                  onTap: () => _open(item),
                                ),
                              ),
                            ),
                          ],
                          InkWell(
                            onTap: _create,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x4dc8b4a0),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('➕', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 8),
                                  Text(
                                    '写一封时光胶囊',
                                    style: TextStyle(
                                      color: Color(0xffa05a67),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
      onPressed: _create,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('写一封胶囊'),
    ),
  );
}

class _CapsuleSectionTitle extends StatelessWidget {
  const _CapsuleSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({
    required this.item,
    required this.highlighted,
    required this.onTap,
  });
  final TimeCapsule item;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntil(DateTime.now());
    return Card(
      color: highlighted
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 108),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: const Text('💌', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.unlocked
                            ? '已在 ${_date(item.unlockDate)} 开启'
                            : days == 0
                            ? '今天可以开启'
                            : '还有 $days 天 · ${_date(item.unlockDate)} 开启',
                      ),
                      if (item.unlocked && item.content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleDetail extends StatelessWidget {
  const _CapsuleDetail({required this.item});
  final TimeCapsule item;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.68,
    maxChildSize: 0.92,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            Icon(item.unlocked ? Icons.lock_open_rounded : Icons.lock_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${_date(item.unlockDate)} 开启'),
        const SizedBox(height: 20),
        if (!item.unlocked)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text('这封信仍被好好锁着。到约定日期后，正文和照片才会出现。'),
            ),
          )
        else ...[
          SelectableText(item.content),
          if (item.images.isNotEmpty) ...[
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: item.images.length,
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      item.images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ],
    ),
  );
}

class _CapsuleEditor extends StatefulWidget {
  const _CapsuleEditor({required this.repository, required this.cache});
  final MemoriesRepository repository;
  final AccountCache cache;

  @override
  State<_CapsuleEditor> createState() => _CapsuleEditorState();
}

class _CapsuleEditorState extends State<_CapsuleEditor> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final List<XFile> _images = [];
  DateTime _unlockDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 30)),
  );
  bool _saving = false;
  String _requestId = '';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    _title.text = await widget.cache.readText('capsule.title.draft');
    _content.text = await widget.cache.readText('capsule.content.draft');
    _requestId = await widget.cache.readText('capsule.request.draft');
    if (_requestId.isEmpty) {
      _requestId = MemoriesRepository.requestId('capsule');
      await widget.cache.writeText('capsule.request.draft', _requestId);
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
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    await widget.cache.writeText('capsule.title.draft', _title.text);
    await widget.cache.writeText('capsule.content.draft', _content.text);
    try {
      final images = <MemoryUploadImage>[];
      for (final image in _images) {
        images.add(
          MemoryUploadImage(
            bytes: await image.readAsBytes(),
            fileName: image.name,
          ),
        );
      }
      await widget.repository.createCapsule(
        requestId: _requestId,
        title: _title.text,
        content: _content.text,
        unlockDate: _unlockDate,
        images: images,
      );
      for (final key in [
        'capsule.title.draft',
        'capsule.content.draft',
        'capsule.request.draft',
      ]) {
        await widget.cache.writeText(key, '');
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
    _content.dispose();
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
          Text('写给未来的我们', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '锁定后无法提前查看正文，请把想说的话确认好。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(labelText: '胶囊标题'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _content,
            minLines: 5,
            maxLines: 12,
            maxLength: 5000,
            decoration: const InputDecoration(labelText: '想留给未来的话'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _unlockDate,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 36500)),
                    );
                    if (selected != null && mounted) {
                      setState(() => _unlockDate = selected);
                    }
                  },
            icon: const Icon(Icons.event_outlined),
            label: Text('${_date(_unlockDate)} 开启'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving || _images.length >= 9 ? null : _pickImages,
            icon: const Icon(Icons.collections_outlined),
            label: Text('选择照片（${_images.length}/9）'),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('照片仅在本次发布时上传，不会作为待上传文件保存。'),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.lock_outline_rounded),
            label: Text(_saving ? '正在封存…' : '封存到未来'),
          ),
        ],
      ),
    ),
  );
}

class _CapsuleEmpty extends StatelessWidget {
  const _CapsuleEmpty({required this.locked, required this.onCreate});
  final bool locked;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_clock_outlined : Icons.mark_email_read_outlined,
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(locked ? '还没有等待未来开启的信' : '到约定的那天，胶囊会出现在这里'),
          if (locked) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onCreate, child: const Text('写第一封')),
          ],
        ],
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

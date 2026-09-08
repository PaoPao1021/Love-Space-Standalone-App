import 'package:flutter/material.dart';

import '../../core/storage/account_cache.dart';
import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class ThanksPage extends StatefulWidget {
  const ThanksPage({required this.repository, required this.cache, super.key});
  final CoreLoopRepository repository;
  final AccountCache cache;

  @override
  State<ThanksPage> createState() => _ThanksPageState();
}

class _ThanksPageState extends State<ThanksPage> {
  late Future<List<MomentEntry>> _items = _load();

  Future<List<MomentEntry>> _load() async =>
      (await widget.repository.moments(tag: '感动')).items;
  void _reload() => setState(() => _items = _load());

  Future<void> _add() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ThanksEditor(repository: widget.repository, cache: widget.cache),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('感谢墙')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add_rounded),
      label: const Text('记录感谢'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<List<MomentEntry>>(
            future: _items,
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volunteer_activism_outlined, size: 56),
                        const SizedBox(height: 14),
                        const Text('还没有记录，想起一件温暖小事了吗？'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _add,
                          child: const Text('夸夸 TA'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _items;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote_rounded),
                            const SizedBox(height: 8),
                            Text(
                              item.content,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            Text(_date(item.eventDate ?? item.createdAt)),
                          ],
                        ),
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
}

class _ThanksEditor extends StatefulWidget {
  const _ThanksEditor({required this.repository, required this.cache});
  final CoreLoopRepository repository;
  final AccountCache cache;

  @override
  State<_ThanksEditor> createState() => _ThanksEditorState();
}

class _ThanksEditorState extends State<_ThanksEditor> {
  final _content = TextEditingController();
  String _requestId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    _content.text = await widget.cache.readText('thanks.content.draft');
    _requestId = await widget.cache.readText('thanks.request.draft');
    if (_requestId.isEmpty) {
      _requestId = CoreLoopRepository.newRequestId('thanks');
      await widget.cache.writeText('thanks.request.draft', _requestId);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.cache.writeText('thanks.content.draft', _content.text);
    try {
      await widget.repository.addThanks(_content.text, requestId: _requestId);
      await widget.cache.writeText('thanks.content.draft', '');
      await widget.cache.writeText('thanks.request.draft', '');
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
          Text('记录感谢', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('具体地说出 TA 做了什么，会比一句“谢谢”更温暖。'),
          const SizedBox(height: 18),
          TextField(
            controller: _content,
            autofocus: true,
            minLines: 4,
            maxLines: 9,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: '让我感动的小事'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '正在保存…' : '放到感谢墙'),
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

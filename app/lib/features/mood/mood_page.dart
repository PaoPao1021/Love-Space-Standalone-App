import 'package:flutter/material.dart';

import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class MoodPage extends StatefulWidget {
  const MoodPage({required this.repository, super.key});
  final CoreLoopRepository repository;
  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
  static const _moods = {
    'happy': '开心',
    'love': '心动',
    'calm': '平静',
    'excited': '兴奋',
    'miss': '想念',
    'grateful': '感恩',
    'tired': '疲惫',
    'anxious': '焦虑',
    'sad': '难过',
    'angry': '生气',
  };
  final _content = TextEditingController();
  String _selected = 'happy';
  bool _private = false;
  bool _saving = false;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<MoodEntry>> _history = widget.repository.moodCalendar(
    _month,
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveMood(
        type: _selected,
        content: _content.text,
        private: _private,
      );
      if (mounted) {
        setState(() => _history = widget.repository.moodCalendar(_month));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('今天的心情已更新')));
      }
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

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _history = widget.repository.moodCalendar(_month);
    });
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('心情日历')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('今天感觉怎么样？', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moods.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _selected == entry.key,
                        onSelected: (_) =>
                            setState(() => _selected = entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _content,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '想说的话（可选）'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('仅自己可见'),
                subtitle: const Text('私密心情不会通知对方'),
                value: _private,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _private = value),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '更新今天的心情'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  IconButton(
                    tooltip: '上个月',
                    onPressed: () => _moveMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_month.year} 年 ${_month.month} 月',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '下个月',
                    onPressed: () => _moveMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              FutureBuilder<List<MoodEntry>>(
                future: _history,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final entries = snapshot.data ?? const [];
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: Text('这个月还没有心情记录')),
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: entries
                        .map(
                          (entry) => Tooltip(
                            message:
                                '${entry.isMine ? '我' : 'TA'} · ${_moods[entry.type] ?? entry.type}${entry.content.isEmpty ? '' : '\n${entry.content}'}',
                            child: Container(
                              width: 72,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${entry.date.day} 日',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _moods[entry.type] ?? entry.type,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

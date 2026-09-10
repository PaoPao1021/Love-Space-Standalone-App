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
    'happy': ('😊', '开心'),
    'love': ('🥰', '甜蜜'),
    'calm': ('😌', '平静'),
    'excited': ('🤩', '兴奋'),
    'miss': ('🥺', '想念'),
    'grateful': ('🙏', '感恩'),
    'tired': ('😴', '疲惫'),
    'anxious': ('😰', '焦虑'),
    'sad': ('😢', '委屈'),
    'angry': ('😤', '生气'),
  };
  final _content = TextEditingController();
  String _selected = 'happy';
  bool _private = false;
  bool _saving = false;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<MoodEntry>> _history = widget.repository.moodCalendar(
    _month,
  );
  late Future<MoodEntry?> _partnerMood;

  @override
  void initState() {
    super.initState();
    _partnerMood = widget.repository.getPartnerMood();
    _restoreToday();
  }

  Future<void> _restoreToday() async {
    try {
      final mood = await widget.repository.getMyMood();
      if (mood != null && mounted) {
        setState(() {
          _selected = _moods.containsKey(mood.type) ? mood.type : _selected;
          _content.text = mood.content;
          _private = mood.visibility == 'self';
        });
      }
    } catch (_) {
      // The editor remains usable when today's saved mood cannot be fetched.
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveMood(
        type: _selected,
        content: _content.text,
        private: _private,
      );
      if (mounted) {
        setState(() {
          _history = widget.repository.moodCalendar(_month);
          _partnerMood = widget.repository.getPartnerMood();
        });
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
    appBar: AppBar(title: const Text('心情打卡')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xffeca8b4),
                      Color(0xfff6dde2),
                      Color(0xffd4c5b0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Text(
                        '今天的心情是...',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: _moods.entries.map((entry) {
                          final v = entry.value;
                          final active = _selected == entry.key;
                          return InkWell(
                            onTap: () => setState(() => _selected = entry.key),
                            borderRadius: BorderRadius.circular(15),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 68,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: active
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x182d2729),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    v.$1,
                                    style: const TextStyle(fontSize: 27),
                                  ),
                                  Text(
                                    v.$2,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff70666a),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 20),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '想说点什么吗？',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _content,
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: '今天发生了什么...',
                          filled: true,
                          fillColor: const Color(0xfff7f5f2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_private ? '仅自己可见' : '双方可见'),
                        subtitle: const Text('可见范围'),
                        value: _private,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _private = value),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '打卡中…' : '打卡'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<MoodEntry?>(
                future: _partnerMood,
                builder: (context, snapshot) {
                  final mood = snapshot.data;
                  if (mood == null) return const SizedBox.shrink();
                  final display = _moods[mood.type] ?? _moods['happy']!;
                  return Container(
                    margin: const EdgeInsets.only(top: 18),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'TA今天的心情',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(display.$1, style: const TextStyle(fontSize: 42)),
                        const SizedBox(height: 4),
                        Text(
                          display.$2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (mood.content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              mood.content,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff70666a),
                                height: 1.55,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                '心情日历',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
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
                                '${entry.isMine ? '我' : 'TA'} · ${_moods[entry.type]?.$2 ?? entry.type}${entry.content.isEmpty ? '' : '\n${entry.content}'}',
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
                                    _moods[entry.type]?.$2 ?? entry.type,
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

import 'dart:math';

import 'package:flutter/material.dart';

import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({required this.repository, super.key});
  final CoreLoopRepository repository;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  QuizQuestion? _active;
  String _answer = '';
  bool _saving = false;
  late Future<({List<QuizQuestion> questions, List<QuizEntry> entries})> _data =
      _load();

  Future<({List<QuizQuestion> questions, List<QuizEntry> entries})>
  _load() async {
    final results = await Future.wait([
      widget.repository.quizQuestions(),
      widget.repository.quizzes(),
    ]);
    return (
      questions: results[0] as List<QuizQuestion>,
      entries: results[1] as List<QuizEntry>,
    );
  }

  void _reload() => setState(() => _data = _load());

  void _start(List<QuizQuestion> questions, List<QuizEntry> entries) {
    final pending = questions.where((question) {
      for (final entry in entries) {
        if (entry.question == question.question) {
          return !entry.bothAnswered && entry.myAnswer.isEmpty;
        }
      }
      return true;
    }).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这一轮题目已经全部完成')));
      return;
    }
    setState(() {
      _active = pending[Random().nextInt(pending.length)];
      _answer = '';
    });
  }

  Future<void> _submit() async {
    final question = _active;
    if (question == null || _answer.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.submitQuiz(question.question, _answer);
      if (!mounted) return;
      setState(() {
        _active = null;
        _answer = '';
      });
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('答案已锁定，等待一起揭晓')));
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('默契测试')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child:
              FutureBuilder<
                ({List<QuizQuestion> questions, List<QuizEntry> entries})
              >(
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
                  final data = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '同一个问题，两个人分别回答',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text('提交前看不到对方答案；双方都回答后才会一起揭晓。'),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _active == null
                                    ? () => _start(data.questions, data.entries)
                                    : null,
                                icon: const Icon(Icons.psychology_alt_outlined),
                                label: const Text('抽一道题'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_active != null) ...[
                        const SizedBox(height: 12),
                        _QuestionCard(
                          question: _active!,
                          answer: _answer,
                          saving: _saving,
                          onAnswer: (value) => setState(() => _answer = value),
                          onSubmit: _submit,
                          onCancel: () => setState(() => _active = null),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        '最近题目',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      if (data.entries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('还没有测试记录，抽一道题开始吧。'),
                          ),
                        )
                      else
                        ...data.entries.map(
                          (entry) => _ResultCard(entry: entry),
                        ),
                    ],
                  );
                },
              ),
        ),
      ),
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.answer,
    required this.saving,
    required this.onAnswer,
    required this.onSubmit,
    required this.onCancel,
  });
  final QuizQuestion question;
  final String answer;
  final bool saving;
  final ValueChanged<String> onAnswer;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.question,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          RadioGroup<String>(
            groupValue: answer,
            onChanged: saving ? (_) {} : (value) => onAnswer(value ?? ''),
            child: Column(
              children: question.options
                  .map(
                    (option) => RadioListTile<String>(
                      value: option,
                      enabled: !saving,
                      title: Text(option),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('换一道'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: answer.isEmpty || saving ? null : onSubmit,
                  child: Text(saving ? '正在提交…' : '锁定答案'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.entry});
  final QuizEntry entry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minTileHeight: 84,
      leading: CircleAvatar(
        child: Icon(
          entry.bothAnswered
              ? entry.matched
                    ? Icons.favorite_rounded
                    : Icons.forum_outlined
              : Icons.hourglass_top_rounded,
        ),
      ),
      title: Text(entry.question),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          entry.bothAnswered
              ? '我：${entry.myAnswer} · TA：${entry.partnerAnswer}'
              : entry.myAnswer.isNotEmpty
              ? '我已回答，等待 TA'
              : entry.partnerAnswered
              ? 'TA 已回答，轮到我了'
              : '等待回答',
        ),
      ),
      trailing: entry.bothAnswered
          ? Text(
              entry.matched ? '默契' : '不同也很好',
              style: const TextStyle(fontWeight: FontWeight.w800),
            )
          : null,
    ),
  );
}

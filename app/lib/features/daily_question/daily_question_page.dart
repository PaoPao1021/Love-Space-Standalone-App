import 'package:flutter/material.dart';

import '../../core/storage/account_cache.dart';
import '../core_loop/core_loop.dart';
import '../core_loop/core_loop_repository.dart';

class DailyQuestionPage extends StatefulWidget {
  const DailyQuestionPage({
    required this.repository,
    required this.cache,
    super.key,
  });
  final CoreLoopRepository repository;
  final AccountCache cache;

  @override
  State<DailyQuestionPage> createState() => _DailyQuestionPageState();
}

class _DailyQuestionPageState extends State<DailyQuestionPage> {
  final _answer = TextEditingController();
  DailyQuestion? _question;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.repository.getDailyQuestion(),
        widget.cache.readText('daily.answer.draft'),
      ]);
      if (!mounted) return;
      final question = values[0] as DailyQuestion;
      _question = question;
      _answer.text = question.myAnswer ?? values[1] as String;
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.cache.writeText('daily.answer.draft', text);
    try {
      final question = await widget.repository.submitDailyAnswer(text);
      await widget.cache.writeText('daily.answer.draft', '');
      if (mounted) setState(() => _question = question);
    } catch (error) {
      if (mounted) setState(() => _error = '提交失败，草稿已保留：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    return Scaffold(
      appBar: AppBar(title: const Text('每日问答')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (question == null)
                  _ErrorCard(message: _error ?? '暂时无法加载', onRetry: _load)
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.category,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            question.question,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _StatusRow(question: question),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _answer,
                    enabled: !question.bothAnswered && !_saving,
                    minLines: 5,
                    maxLines: 9,
                    maxLength: 500,
                    onChanged: (value) =>
                        widget.cache.writeText('daily.answer.draft', value),
                    decoration: const InputDecoration(
                      labelText: '我的回答',
                      hintText: '只有双方都回答后，彼此答案才会揭晓',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: question.bothAnswered || _saving
                        ? null
                        : _submit,
                    child: Text(
                      _saving
                          ? '正在提交…'
                          : question.myAnswer == null
                          ? '提交回答'
                          : '更新回答',
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (question.bothAnswered) ...[
                    const SizedBox(height: 24),
                    Text('一起揭晓', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _AnswerCard(label: '我的回答', answer: question.myAnswer ?? ''),
                    const SizedBox(height: 12),
                    _AnswerCard(
                      label: 'TA 的回答',
                      answer: question.partnerAnswer ?? '',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '双方揭晓后，今天的答案会被锁定。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.question});
  final DailyQuestion question;
  @override
  Widget build(BuildContext context) {
    final text = question.bothAnswered
        ? '双方已回答，可以揭晓'
        : question.myAnswer == null
        ? '等待你回答'
        : question.partnerAnswered
        ? 'TA 已回答，等待揭晓'
        : '已提交，等待 TA';
    return Row(
      children: [
        Icon(
          question.bothAnswered
              ? Icons.lock_outline_rounded
              : Icons.hourglass_bottom_rounded,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.label, required this.answer});
  final String label;
  final String answer;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(answer),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(message),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: onRetry, child: const Text('重试')),
    ],
  );
}

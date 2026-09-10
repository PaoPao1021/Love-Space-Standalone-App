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
      appBar: AppBar(title: const Text('今日问答')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (question == null)
                  _ErrorCard(message: _error ?? '暂时无法加载', onRetry: _load)
                else ...[
                  Text(
                    'DAILY CONNECTION · ${question.category}'.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xffa05a67),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xff2d2729),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x252d2729),
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '01',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontStyle: FontStyle.italic,
                              fontSize: 34,
                              color: Color(0x44ffffff),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            question.question,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '先独立作答，双方完成后才能看到彼此的答案',
                            style: TextStyle(
                              color: Color(0x99ffffff),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (question.myAnswer == null)
                    _Editor(
                      answer: _answer,
                      saving: _saving,
                      onSubmit: _submit,
                      onChanged: (v) {
                        widget.cache.writeText('daily.answer.draft', v);
                        setState(() {});
                      },
                    )
                  else ...[
                    _AnswerCard(
                      label: '我的回答',
                      answer: question.myAnswer ?? '',
                      accent: const Color(0xffe85d75),
                    ),
                    const SizedBox(height: 12),
                    if (question.bothAnswered)
                      _AnswerCard(
                        label: 'TA 的回答',
                        answer: question.partnerAnswer ?? '',
                        accent: const Color(0xffd7b48d),
                      )
                    else
                      _Waiting(partnerAnswered: question.partnerAnswered),
                  ],
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
                  const Padding(
                    padding: EdgeInsets.only(top: 34),
                    child: Center(
                      child: Text(
                        '每天一个问题，把重要的话留给彼此。',
                        style: TextStyle(
                          color: Color(0xffaaa0a2),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.answer,
    required this.accent,
  });
  final String label;
  final String answer;
  final Color accent;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(20),
      border: Border(left: BorderSide(color: accent, width: 4)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff9b6b73),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(answer, style: const TextStyle(fontSize: 16, height: 1.7)),
        ],
      ),
    ),
  );
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.answer,
    required this.saving,
    required this.onSubmit,
    required this.onChanged,
  });
  final TextEditingController answer;
  final bool saving;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '我的回答',
          style: TextStyle(
            color: Color(0xff9b6b73),
            fontWeight: FontWeight.bold,
          ),
        ),
        TextField(
          controller: answer,
          minLines: 5,
          maxLines: 9,
          maxLength: 500,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            hintText: '慢慢写，真实比完美更重要…',
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${answer.text.length} / 500',
              style: const TextStyle(fontSize: 11, color: Color(0xffaaa0a2)),
            ),
            SizedBox(
              width: 112,
              child: FilledButton(
                onPressed: answer.text.trim().isEmpty || saving
                    ? null
                    : onSubmit,
                child: Text(saving ? '保存中…' : '保存回答'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.partnerAnswered});
  final bool partnerAnswered;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        const Text(
          '···',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 30,
            color: Color(0xffe85d75),
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '等待 TA 的回答',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          partnerAnswered ? 'TA 已经回答，刷新后即可揭晓' : '不催促，也是一种温柔。回答会为你保密。',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff93898c), fontSize: 13),
        ),
      ],
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

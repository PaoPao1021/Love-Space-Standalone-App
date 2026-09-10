import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../core_loop/core_loop_repository.dart';

/// Native equivalent of the mini-program's create/join space step, after login.
class ConnectPage extends StatefulWidget {
  const ConnectPage({required this.auth, required this.repository, super.key});
  final AuthController auth;
  final CoreLoopRepository repository;
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  bool _join = false, _saving = false;
  DateTime _date = DateTime.now();
  String? _error;
  late final TextEditingController _name = TextEditingController(
    text: widget.auth.user?.displayName ?? '',
  );
  final _invite = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '请输入昵称');
      return;
    }
    if (_join &&
        !RegExp(
          r'^[23456789A-HJ-NP-Z]{6}$',
        ).hasMatch(_invite.text.trim().toUpperCase())) {
      setState(() => _error = '请输入六位邀请码');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.apiClient.post(
        '/api/v1/functions/couple',
        body: {
          'action': _join ? 'join' : 'create',
          'data': {
            'nickName': _name.text.trim(),
            'avatarUrl': widget.auth.user?.avatarUrl ?? '',
            if (_join)
              'inviteCode': _invite.text.trim().toUpperCase()
            else
              'startDate':
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          },
        },
      );
      await widget.auth.refreshUser();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        TextButton(
          onPressed: _saving ? null : widget.auth.logout,
          child: const Text('退出'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Text('🏡', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 20),
              const Text(
                '把爱落在每一天',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text('记录、倾听、一起计划。这里只属于你们两个人。', textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('创建空间')),
                  ButtonSegment(value: true, label: Text('加入空间')),
                ],
                selected: {_join},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _join = value.single),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '我的昵称'),
                maxLength: 30,
              ),
              const SizedBox(height: 12),
              if (_join)
                TextField(
                  controller: _invite,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: '对方的邀请码'),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在一起日期'),
                  subtitle: Text('${_date.year}年${_date.month}月${_date.day}日'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null && mounted) {
                      setState(() => _date = selected);
                    }
                  },
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? '正在保存…'
                      : _join
                      ? '加入我们的空间'
                      : '创建双人空间',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

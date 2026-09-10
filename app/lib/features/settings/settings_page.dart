import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme/background_preferences.dart';
import '../core_loop/core_loop_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.auth,
    required this.repository,
    required this.background,
    super.key,
  });
  final AuthController auth;
  final CoreLoopRepository repository;
  final BackgroundPreferences background;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nickname = TextEditingController();
  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  late Future<Map<String, dynamic>> _info = _load();
  Future<Map<String, dynamic>> _load() => widget.repository.apiClient.post(
    '/api/v1/functions/couple',
    body: const {'action': 'getInfo'},
  );
  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作未完成：$error')));
    }
  }

  Future<void> _editNickname() async {
    final input = _nickname..text = widget.auth.user?.nickname ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: input,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '输入新昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // Keep the controller alive through the dialog's reverse transition.
    if (name == null || name.isEmpty) return;
    try {
      await widget.repository.updateProfile(nickname: name);
      await widget.auth.refreshUser();
      if (mounted) setState(() => _info = _load());
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _chooseBackground() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 2400,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await widget.background.save(bytes: bytes);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _backgroundPanel() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AnimatedBuilder(
      animation: widget.background,
      builder: (context, _) {
        final bg = widget.background;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '自定义背景',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '选择一张图片作为全屏背景，设置透明度营造沉浸感',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (bg.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Opacity(
                      opacity: bg.opacity,
                      child: Image.memory(
                        bg.image!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _chooseBackground,
                        child: Text(bg.image == null ? '选择图片' : '更换背景'),
                      ),
                    ),
                    if (bg.image != null) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => bg.save(reset: true),
                        child: const Text('恢复默认'),
                      ),
                    ],
                  ],
                ),
                if (bg.image != null) ...[
                  const SizedBox(height: 20),
                  Text('背景透明度 ${(bg.opacity * 100).round()}%'),
                  Slider(
                    value: bg.opacity,
                    min: .1,
                    max: 1,
                    divisions: 90,
                    onChanged: (v) => bg.save(value: v),
                  ),
                  const Text(
                    '数值越小背景越透明 · 100% = 完全显示',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in [
                        (.3, '朦胧'),
                        (.5, '柔和'),
                        (.7, '清晰'),
                        (.9, '明亮'),
                      ])
                        ChoiceChip(
                          label: Text(
                            '${(preset.$1 * 100).round()}% ${preset.$2}',
                          ),
                          selected: (bg.opacity - preset.$1).abs() < .005,
                          onSelected: (_) => bg.save(value: preset.$1),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
  Future<void> _dissolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除绑定'),
        content: const Text('解除后所有数据将保留但无法再共享，确定要解除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除绑定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.apiClient.post(
        '/api/v1/functions/couple',
        body: const {'action': 'dissolve'},
      );
      await widget.auth.refreshUser();
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _info,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _info = _load()),
              child: const Text('加载失败，点按重试'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final couple = data['couple'] as Map<String, dynamic>? ?? {};
        final user = data['user'] as Map<String, dynamic>? ?? {};
        final invite = couple['inviteCode']?.toString() ?? '';
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _group('个人信息', [
              ListTile(
                title: const Text('我的昵称'),
                trailing: Text(
                  user['nickName']?.toString() ??
                      widget.auth.user?.displayName ??
                      '未设置',
                ),
                onTap: _editNickname,
              ),
            ]),
            _group('关系', [
              ListTile(
                title: const Text('在一起日期'),
                trailing: Text(couple['startDate']?.toString() ?? ''),
              ),
              if (data['partner'] == null && invite.isNotEmpty)
                ListTile(
                  title: const Text('邀请码'),
                  trailing: Text(invite),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: invite));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
                    }
                  },
                ),
            ]),
            _group('个性化', [
              ListTile(
                title: const Text('自定义背景'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _backgroundPanel,
              ),
            ]),
            _group('隐私与数据', [
              ListTile(
                title: const Text('双人空间保护'),
                subtitle: const Text('内容仅通过服务端按情侣关系校验访问'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('双人空间保护'),
                    content: const Text(
                      '相册、心情、问答与共同记录均通过服务端校验情侣关系。心情选择“仅自己”后，对方无法查看。自定义背景仅保存在当前设备的账号缓存中。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('知道了'),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            _group('关于', [
              const ListTile(title: Text('版本'), trailing: Text('1.0.0')),
            ]),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _dissolve,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('解除绑定'),
            ),
          ],
        );
      },
    ),
  );
  Widget _group(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

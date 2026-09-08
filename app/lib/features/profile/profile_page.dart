import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_models.dart';
import '../../core/push/push_client.dart';
import '../../core/storage/account_cache.dart';
import '../core_loop/core_loop_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.user,
    required this.authController,
    required this.repository,
    required this.cache,
    required this.pushClient,
    super.key,
  });
  final LoveSpaceUser user;
  final AuthController authController;
  final CoreLoopRepository repository;
  final AccountCache cache;
  final PushClient pushClient;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<PushStatus> _pushStatus = widget.pushClient.status();
  bool _enablingPush = false;

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: widget.user.nickname);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await widget.repository.updateProfile(nickname: value);
    await widget.authController.refreshUser();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称已更新')));
    }
  }

  Future<void> _editAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    try {
      final uploaded = await widget.repository.apiClient.uploadBytes(
        '/api/v1/files/images',
        bytes: await image.readAsBytes(),
        fileName: image.name,
      );
      final assetId = uploaded['fileID'] as String? ?? '';
      if (assetId.isEmpty) throw StateError('头像上传响应无效');
      await widget.repository.updateProfile(
        nickname: widget.user.displayName,
        avatarAssetId: assetId,
      );
      await widget.authController.refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像已更新')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: '旧密码'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: '新密码（至少 8 位）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
    if (value != true) {
      oldPassword.dispose();
      newPassword.dispose();
      return;
    }
    try {
      await widget.authController.repository.changePassword(
        oldPassword.text,
        newPassword.text,
      );
      await widget.cache.clearAccount();
      await widget.authController.passwordChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      oldPassword.dispose();
      newPassword.dispose();
    }
  }

  Future<void> _enablePush() async {
    final consented = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开启系统通知'),
        content: Text(
          kIsWeb
              ? 'LoveSpace 会向浏览器登记一个 Web Push 订阅，用来接收你们两人的新动态。订阅信息不会用于其他用途。'
              : 'LoveSpace 会在你同意后初始化个推，并登记本机 CID，用来接收你们两人的新动态。CID 不会用于广告或其他用途。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不开启'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('同意并继续'),
          ),
        ],
      ),
    );
    if (consented != true || !mounted) return;
    setState(() => _enablingPush = true);
    try {
      final registration = await widget.pushClient.enable();
      await widget.repository.registerPush(
        deviceId: registration.deviceId,
        platform: registration.platform,
        provider: registration.provider,
        endpoint: registration.endpoint,
        publicKey: registration.publicKey,
        authSecret: registration.authSecret,
      );
      if (mounted) {
        setState(() => _pushStatus = widget.pushClient.status());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('通知已开启')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _enablingPush = false);
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final release = await widget.repository.latestAndroidRelease();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('最新版本 ${release.version}'),
          content: SelectableText(
            '${release.notes}\n\nSHA-256\n${release.sha256}\n\n下载地址\n${release.downloadUrl}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('检查更新失败：$error')));
      }
    }
  }

  Future<void> _logout({bool all = false}) async {
    await widget.cache.clearAccount();
    if (all) {
      await widget.authController.logoutAll();
    } else {
      await widget.authController.logout();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('个人中心')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: '修改头像',
                        child: InkWell(
                          onTap: _editAvatar,
                          borderRadius: BorderRadius.circular(40),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 31,
                                foregroundImage: widget.user.avatarUrl.isEmpty
                                    ? null
                                    : NetworkImage(widget.user.avatarUrl),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 30,
                                ),
                              ),
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 11,
                                  child: Icon(
                                    Icons.photo_camera_outlined,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.user.username,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '修改昵称',
                        onPressed: _editNickname,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '通知与设备',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              FutureBuilder<PushStatus>(
                future: _pushStatus,
                builder: (context, snapshot) {
                  final status = snapshot.data;
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: const Text('系统通知'),
                          subtitle: Text(status?.message ?? '正在检查…'),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: FilledButton(
                            onPressed:
                                status?.supported == false || _enablingPush
                                ? null
                                : _enablePush,
                            child: Text(
                              _enablingPush
                                  ? '正在开启…'
                                  : status?.enabled == true
                                  ? '重新登记通知'
                                  : '开启通知',
                            ),
                          ),
                        ),
                        if (kIsWeb && status?.installed == false)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              'iPhone：用 Safari 打开 → 分享 → 添加到主屏幕；从主屏幕进入后，再点“开启通知”。',
                            ),
                          ),
                        if (!kIsWeb)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              '一加 / ColorOS：请允许通知，并在系统设置中允许后台运行、关闭电池优化。手动“强制停止”后系统不会继续投递；应用内通知中心始终是事实来源。',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              if (!kIsWeb)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: const Icon(Icons.system_update_outlined),
                    title: const Text('检查 Android 更新'),
                    subtitle: const Text('核对版本、下载地址与 SHA-256'),
                    onTap: _checkUpdate,
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                '账号安全',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      minTileHeight: 64,
                      leading: const Icon(Icons.password_outlined),
                      title: const Text('修改密码'),
                      subtitle: const Text('修改后所有设备需要重新登录'),
                      onTap: _changePassword,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      minTileHeight: 64,
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('退出当前设备'),
                      onTap: _logout,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      minTileHeight: 64,
                      leading: Icon(
                        Icons.phonelink_erase_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        '退出全部设备',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () => _logout(all: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'LoveSpace 仅供你们两人使用。推送受系统后台策略影响，重要消息也会保留在通知中心。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

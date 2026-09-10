import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late final Future<_CoupleProfile> _couple = _loadCouple();
  bool _enablingPush = false;

  Future<_CoupleProfile> _loadCouple() async {
    final result = await widget.repository.apiClient.post(
      '/api/v1/functions/couple',
      body: const {'action': 'getInfo'},
    );
    final couple = result['couple'] as Map<String, dynamic>?;
    final partner = result['partner'] as Map<String, dynamic>?;
    return _CoupleProfile(
      startDate: DateTime.tryParse(couple?['startDate']?.toString() ?? ''),
      partnerName: partner?['nickName'] as String? ?? 'TA',
      partnerAvatar: partner?['avatarUrl'] as String? ?? '',
      bound: couple != null,
    );
  }

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
    backgroundColor: const Color(0xFFF8F5F3),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 32),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                decoration: const BoxDecoration(color: Color(0xFFF8F5F3)),
                child: Column(
                  children: [
                    const Text(
                      'OUR SPACE',
                      style: TextStyle(
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA05A67),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
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
                                  radius: 37,
                                  backgroundImage: const AssetImage(
                                    'assets/reference/default-avatar.png',
                                  ),
                                  foregroundImage: widget.user.avatarUrl.isEmpty
                                      ? null
                                      : NetworkImage(widget.user.avatarUrl),
                                ),
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    backgroundColor: Color(0xFFE85D75),
                                    foregroundColor: Colors.white,
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
                        FutureBuilder<_CoupleProfile>(
                          future: _couple,
                          builder: (context, snapshot) {
                            final info = snapshot.data;
                            if (info?.bound != true) {
                              return const SizedBox.shrink();
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '♥',
                                  style: TextStyle(
                                    color: Color(0xFFE85D75),
                                    fontSize: 19,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                CircleAvatar(
                                  radius: 29,
                                  backgroundImage: const AssetImage(
                                    'assets/reference/default-avatar.png',
                                  ),
                                  foregroundImage: info!.partnerAvatar.isEmpty
                                      ? null
                                      : NetworkImage(info.partnerAvatar),
                                ),
                                const SizedBox(width: 12),
                              ],
                            );
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<_CoupleProfile>(
                                future: _couple,
                                builder: (context, snapshot) => Text(
                                  snapshot.data?.bound == true
                                      ? '${widget.user.displayName}  &  ${snapshot.data!.partnerName}'
                                      : widget.user.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: const Color(0xFF2D2729),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '点击名字可以修改昵称',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF948A8D)),
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
                    const SizedBox(height: 12),
                    FutureBuilder<_CoupleProfile>(
                      future: _couple,
                      builder: (context, snapshot) {
                        final date = snapshot.data?.startDate;
                        final days = date == null
                            ? null
                            : DateTime.now()
                                  .difference(
                                    DateTime(date.year, date.month, date.day),
                                  )
                                  .inDays
                                  .abs();
                        return Text(
                          days == null ? '属于你们两个人的小世界' : '共同走过 $days 天',
                          style: const TextStyle(
                            color: Color(0xFF948A8D),
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _FeatureLink(
                      dark: true,
                      kicker: '每天 5 分钟',
                      title: '今日问答',
                      onTap: () => context.push('/daily-question'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FeatureLink(
                      kicker: '看见关系变化',
                      title: '关系月报',
                      onTap: () => context.push('/monthly-report'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '共同生活',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _ProfileMenu(
                items: [
                  _ProfileMenuItem(
                    '◇',
                    const Color(0xFFF8DFE4),
                    '纪念日',
                    '重要日期',
                    () => context.push('/anniversaries'),
                  ),
                  _ProfileMenuItem(
                    '◌',
                    const Color(0xFFEEE2D2),
                    '心情记录',
                    '彼此看见',
                    () => context.push('/mood'),
                  ),
                  _ProfileMenuItem(
                    '✓',
                    const Color(0xFFE2ECE4),
                    '共同任务',
                    '一起完成',
                    () => context.push('/tasks'),
                  ),
                  _ProfileMenuItem(
                    '⌁',
                    const Color(0xFFF4E1D8),
                    '今天吃什么',
                    '共同点菜',
                    () => context.push('/menu'),
                  ),
                  _ProfileMenuItem(
                    '♡',
                    const Color(0xFFEAE4F0),
                    '爱心积分',
                    '让付出被看见',
                    () => context.push('/points'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '珍藏与互动',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8F8386),
                ),
              ),
              const SizedBox(height: 8),
              _ProfileMenu(
                items: [
                  _ProfileMenuItem(
                    '☆',
                    const Color(0xFFE1EAF0),
                    '愿望清单',
                    '',
                    () => context.push('/wishes'),
                  ),
                  _ProfileMenuItem(
                    '□',
                    const Color(0xFFF8DFE4),
                    '时光胶囊',
                    '',
                    () => context.push('/capsules'),
                  ),
                  _ProfileMenuItem(
                    '＋',
                    const Color(0xFFE2ECE4),
                    '感谢墙',
                    '',
                    () => context.push('/thanks'),
                  ),
                  _ProfileMenuItem(
                    '?',
                    const Color(0xFFEEE2D2),
                    '默契测试',
                    '',
                    () => context.push('/quiz'),
                  ),
                  _ProfileMenuItem(
                    '⌇',
                    const Color(0xFFF4E1D8),
                    '回忆时间轴',
                    '',
                    () => context.push('/timeline'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _ProfileMenu(
                items: [
                  _ProfileMenuItem(
                    '··',
                    const Color(0xFFEEE9EA),
                    '设置与隐私',
                    '',
                    () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
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
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
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

class _FeatureLink extends StatelessWidget {
  const _FeatureLink({
    required this.kicker,
    required this.title,
    required this.onTap,
    this.dark = false,
  });
  final String kicker;
  final String title;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) => Material(
    color: dark ? const Color(0xFF2D2729) : const Color(0xFFF0DFC9),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        height: 104,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker,
                style: TextStyle(
                  fontSize: 11,
                  color: dark
                      ? Colors.white60
                      : const Color(0xFF3A3033).withValues(alpha: .6),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : const Color(0xFF3A3033),
                      ),
                    ),
                  ),
                  Text(
                    '→',
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF3A3033),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CoupleProfile {
  const _CoupleProfile({
    required this.startDate,
    required this.partnerName,
    required this.partnerAvatar,
    required this.bound,
  });
  final DateTime? startDate;
  final String partnerName;
  final String partnerAvatar;
  final bool bound;
}

class _ProfileMenuItem {
  const _ProfileMenuItem(
    this.symbol,
    this.color,
    this.label,
    this.note,
    this.onTap,
  );
  final String symbol;
  final Color color;
  final String label;
  final String note;
  final VoidCallback onTap;
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.items});
  final List<_ProfileMenuItem> items;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C3C282D),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        return Column(
          children: [
            ListTile(
              minTileHeight: 58,
              onTap: item.onTap,
              leading: Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(item.symbol, style: const TextStyle(fontSize: 18)),
              ),
              title: Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFF3B3235),
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.note.isNotEmpty)
                    Text(
                      item.note,
                      style: const TextStyle(
                        color: Color(0xFFAAA0A2),
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(width: 6),
                  const Text(
                    '›',
                    style: TextStyle(color: Color(0xFFC0B6B8), fontSize: 24),
                  ),
                ],
              ),
            ),
            if (entry.key != items.length - 1)
              const Divider(height: 1, indent: 62),
          ],
        );
      }).toList(),
    )),
  );
}

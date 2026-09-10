import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import 'album.dart';
import 'album_repository.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({required this.repository, super.key});

  final AlbumRepository repository;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<List<Album>> _albums = widget.repository.listAlbums();

  Future<void> _reload() async {
    final request = widget.repository.listAlbums();
    setState(() => _albums = request);
    try {
      await request;
    } catch (_) {
      // FutureBuilder renders the retry state for this same request.
    }
  }

  Future<void> _createAlbum() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CreateAlbumForm(repository: widget.repository),
    );
    if (created == true && mounted) {
      await _reload();
    }
  }

  Future<void> _chooseAlbumForUpload() async {
    try {
      final albums = await _albums;
      if (!mounted) return;
      if (albums.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先创建相册')));
        return;
      }
      final selected = await showModalBottomSheet<Album>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('选择要上传到的相册')),
          ...albums.map((album) => ListTile(
            leading: Text(_albumEmoji(album.name), style: const TextStyle(fontSize: 23)),
            title: Text(album.name), subtitle: Text('${album.photoCount}张照片'),
            onTap: () => Navigator.pop(context, album),
          )),
        ])),
      );
      if (selected != null && mounted) _openAlbum(selected, upload: true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('相册加载失败，请重试')));
    }
  }

  static String _albumEmoji(String name) => switch (name) {
    '日常' => '📱', '约会' => '💑', '旅行' => '✈️', '美食' => '🍜', '自拍' => '🤳', '节日' => '🎄', _ => '📁',
  };

  Future<void> _renameAlbum(Album album) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _CreateAlbumForm(repository: widget.repository, existing: album),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _deleteAlbum(Album album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          title: Text('删除“${album.name}”？'),
          content: const Text('相册内的照片也会一起删除，此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteAlbum(album.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除“${album.name}”')));
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _openAlbum(Album album, {bool upload = false}) {
    context
        .push(
          '/album/${Uri.encodeComponent(album.id)}'
          '?name=${Uri.encodeQueryComponent(album.name)}${upload ? '&upload=1' : ''}',
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F5F3),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 1180
                  ? 1180.0
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  height: constraints.maxHeight,
                  child: FutureBuilder<List<Album>>(
                    future: _albums,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _AlbumMessageState(
                          icon: Icons.cloud_off_outlined,
                          title: '没有读到相册',
                          message: '请检查网络后重试。',
                          actionLabel: '重新加载',
                          onAction: _reload,
                        );
                      }
                      final albums = snapshot.data ?? const [];
                      if (albums.isEmpty) {
                        return _AlbumMessageState(
                          icon: Icons.photo_library_outlined,
                          title: '还没有相册',
                          message: '新建一个相册，放进你们的第一张照片。',
                          actionLabel: '新建第一个相册',
                          onAction: _createAlbum,
                        );
                      }
                      final columns = contentWidth >= 1000
                          ? 4
                          : contentWidth >= 680
                          ? 3
                          : 2;
                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 110),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.73,
                              ),
                          itemCount: albums.length,
                          itemBuilder: (context, index) {
                            final album = albums[index];
                            return _AlbumCard(
                              album: album,
                              onTap: () => _openAlbum(album),
                              onRename: () => _renameAlbum(album),
                              onDelete: album.isDefault
                                  ? null
                                  : () => _deleteAlbum(album),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(color: Color(0xF2FFFFFF), boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, -2))]),
            child: Row(children: [
              Expanded(child: FilledButton(onPressed: _chooseAlbumForUpload, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE85D75), foregroundColor: Colors.white, shape: const StadiumBorder()), child: const Text('上传照片'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: _createAlbum, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFA05A67), backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFF0EDEA)), shape: const StadiumBorder()), child: const Text('新建相册'))),
            ]),
          ),
        ),
      ],
    ));
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.onRename,
    this.onDelete,
  });

  final Album album;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AlbumCover(url: album.coverUrl, emoji: _emoji(album.name)),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: colors.scrim.withValues(alpha: 0.48),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: '相册选项',
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'rename') onRename();
                          if (value == 'delete') onDelete!();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.drive_file_rename_outline),
                              title: Text('重命名'),
                            ),
                          ),
                          if (onDelete != null)
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.delete_outline_rounded),
                                title: Text('删除相册'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF2D2729),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${album.photoCount}张',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF948A8D), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  static String _emoji(String name) => switch (name) {
    '日常' => '📱', '约会' => '💑', '旅行' => '✈️', '美食' => '🍜', '自拍' => '🤳', '节日' => '🎄', _ => '📁',
  };
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.url, required this.emoji});

  final String url;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _CoverPlaceholder(emoji: emoji);
    return Image.network(
      url,
      fit: BoxFit.cover,
      semanticLabel: '相册封面',
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _CoverPlaceholder(emoji: emoji, loading: true),
      errorBuilder: (_, _, _) => _CoverPlaceholder(emoji: emoji),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.emoji, this.loading = false});

  final String emoji;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F2ED),
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Text(emoji, style: const TextStyle(fontSize: 42)),
      ),
    );
  }
}

class _AlbumMessageState extends StatelessWidget {
  const _AlbumMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final FutureOrVoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 72),
        Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Center(
          child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ),
      ],
    );
  }
}

typedef FutureOrVoidCallback = void Function();

class _CreateAlbumForm extends StatefulWidget {
  const _CreateAlbumForm({required this.repository, this.existing});

  final AlbumRepository repository;
  final Album? existing;

  @override
  State<_CreateAlbumForm> createState() => _CreateAlbumFormState();
}

class _CreateAlbumFormState extends State<_CreateAlbumForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing == null) {
        await widget.repository.addAlbum(_nameController.text);
      } else {
        await widget.repository.renameAlbum(
          widget.existing!.id,
          _nameController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法保存相册，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? '新建相册' : '重命名相册',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '给一段共同回忆取个名字。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 30,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: '相册名称',
                  hintText: '例如：第一次旅行',
                  prefixIcon: Icon(Icons.photo_album_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '请输入相册名称';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.existing == null ? '创建相册' : '保存名称'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

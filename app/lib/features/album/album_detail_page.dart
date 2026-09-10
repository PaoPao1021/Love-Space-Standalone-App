import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import 'album.dart';
import 'album_repository.dart';

class AlbumDetailPage extends StatefulWidget {
  const AlbumDetailPage({
    required this.repository,
    required this.albumId,
    required this.albumName,
    this.uploadOnOpen = false,
    super.key,
  });

  final AlbumRepository repository;
  final String albumId;
  final String albumName;
  final bool uploadOnOpen;

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final ImagePicker _picker = ImagePicker();
  final List<AlbumPhoto> _photos = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _uploading = false;
  int _page = 0;
  int _uploaded = 0;
  int _uploadTotal = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    if (widget.uploadOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickAndUpload();
      });
    }
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;
    if (reset) {
      setState(() {
        _loading = _photos.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final nextPage = reset ? 1 : _page + 1;
      final result = await widget.repository.listPhotos(
        widget.albumId,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _photos.clear();
        _photos.addAll(result.items);
        _page = nextPage;
        _hasMore = result.hasMore;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '没有读到照片，请检查网络后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    try {
      final selected = await _picker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (selected.isEmpty || !mounted) return;
      final files = selected.take(20).toList(growable: false);
      if (selected.length > 20) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('一次最多上传 20 张，已选择前 20 张')));
      }

      final pending = <PendingPhoto>[];
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        if (await file.length() > 10 * 1024 * 1024) {
          throw const ApiException('单张图片不能超过 10MB');
        }
        pending.add(
          PendingPhoto(
            bytes: await file.readAsBytes(),
            fileName: file.name.isEmpty ? 'photo-$index.jpg' : file.name,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _uploading = true;
        _uploaded = 0;
        _uploadTotal = pending.length;
      });
      await widget.repository.uploadPhotos(
        widget.albumId,
        pending,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _uploaded = completed;
              _uploadTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      await _load(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已上传 ${pending.length} 张照片')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('照片上传失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openPhoto(AlbumPhoto photo) async {
    final action = await showDialog<_PhotoAction>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        var favorite = photo.isFavorite;
        var changingFavorite = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: '关闭预览',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.albumName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: favorite ? '取消收藏' : '收藏照片',
                            onPressed: changingFavorite
                                ? null
                                : () async {
                                    setDialogState(
                                      () => changingFavorite = true,
                                    );
                                    try {
                                      final value = await widget.repository
                                          .toggleFavorite(photo.id);
                                      if (!mounted || !context.mounted) return;
                                      setState(() {
                                        final index = _photos.indexWhere(
                                          (item) => item.id == photo.id,
                                        );
                                        if (index >= 0) {
                                          _photos[index] = _photos[index]
                                              .copyWith(isFavorite: value);
                                        }
                                      });
                                      setDialogState(() => favorite = value);
                                    } on ApiException catch (error) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(error.message),
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setDialogState(
                                          () => changingFavorite = false,
                                        );
                                      }
                                    }
                                  },
                            icon: changingFavorite
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    favorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: favorite
                                        ? const Color(0xFFF472B6)
                                        : Colors.white,
                                  ),
                          ),
                          IconButton(
                            tooltip: '删除照片',
                            onPressed: () => Navigator.pop(
                              dialogContext,
                              _PhotoAction.delete,
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5,
                        child: Center(
                          child: Image.network(
                            photo.url,
                            fit: BoxFit.contain,
                            semanticLabel: photo.description.isEmpty
                                ? '相册照片'
                                : photo.description,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                            errorBuilder: (_, _, _) => const _PreviewError(),
                          ),
                        ),
                      ),
                    ),
                    if (photo.description.isNotEmpty ||
                        photo.location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        child: Column(
                          children: [
                            if (photo.description.isNotEmpty)
                              Text(
                                photo.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            if (photo.location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                photo.location,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (action == _PhotoAction.delete && mounted) {
      await _confirmDeletePhoto(photo);
    }
  }

  Future<void> _confirmDeletePhoto(AlbumPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('删除这张照片？'),
          content: const Text('删除后无法恢复。'),
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
      await widget.repository.deletePhoto(photo.id);
      if (!mounted) return;
      setState(() => _photos.removeWhere((item) => item.id == photo.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照片已删除')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F3),
      appBar: AppBar(
        title: Text(widget.albumName),
        actions: [
          IconButton(
            tooltip: '上传照片',
            onPressed: _uploading ? null : _pickAndUpload,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_uploading)
            Semantics(
              liveRegion: true,
              label: '正在上传第 $_uploaded 张，共 $_uploadTotal 张',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: _uploadTotal == 0 ? null : _uploaded / _uploadTotal,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      '正在上传 $_uploaded / $_uploadTotal',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _photos.isEmpty) {
      return _PhotoMessageState(
        icon: Icons.cloud_off_outlined,
        title: '没有读到照片',
        message: _error!,
        actionLabel: '重新加载',
        onAction: () => _load(reset: true),
      );
    }
    if (_photos.isEmpty) {
      return _PhotoMessageState(
        icon: Icons.add_photo_alternate_outlined,
        title: '相册还是空的',
        message: '选几张照片，把这一刻留在你们的空间里。',
        actionLabel: '选择照片',
        onAction: _pickAndUpload,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 700
            ? 4
            : 3;
        return RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final photo = _photos[index];
                    return _PhotoTile(
                      photo: photo,
                      onTap: () => _openPhoto(photo),
                    );
                  }, childCount: _photos.length),
                ),
              ),
              if (_hasMore)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: FilledButton.tonal(
                        onPressed: _loadingMore
                            ? null
                            : () => _load(reset: false),
                        child: _loadingMore
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                ),
                              )
                            : const Text('加载更多'),
                      ),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onTap});

  final AlbumPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F2ED),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.previewUrl,
              fit: BoxFit.cover,
              semanticLabel: photo.description.isEmpty
                  ? '相册照片'
                  : photo.description,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 34),
              ),
            ),
            if (photo.isFavorite)
              const Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 18,
                      color: Color(0xFFF9A8D4),
                      semanticLabel: '已收藏',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoMessageState extends StatelessWidget {
  const _PhotoMessageState({
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
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 90),
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

class _PreviewError extends StatelessWidget {
  const _PreviewError();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white70, size: 54),
        SizedBox(height: 12),
        Text('照片暂时无法显示', style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}

enum _PhotoAction { delete }

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/lovespace_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.currentIndex,
    required this.child,
    this.onSelect,
    super.key,
  });

  final int currentIndex;
  final Widget child;
  final ValueChanged<int>? onSelect;

  static const _paths = ['/home', '/album', '/moments', '/profile'];
  static const _labels = ['首页', '相册', '点滴', '我的'];
  static const _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.photo_library_outlined, Icons.photo_library_rounded),
    (Icons.auto_awesome_outlined, Icons.auto_awesome),
    (Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .72),
            ),
            boxShadow: [
              BoxShadow(
                color: LoveSpaceColors.ink.withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_paths.length, (index) {
              final active = index == currentIndex;
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: _labels[index],
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: active
                          ? null
                          : () {
                              if (onSelect != null) {
                                onSelect!(index);
                              } else {
                                context.go(_paths[index]);
                              }
                            },
                      borderRadius: BorderRadius.circular(16),
                      splashColor: scheme.primary.withValues(alpha: .08),
                      highlightColor: Colors.transparent,
                      child: Center(
                        child: AnimatedContainer(
                          duration: motion,
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? scheme.primary.withValues(alpha: .11)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active ? _icons[index].$2 : _icons[index].$1,
                                size: 22,
                                color: active
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _labels[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: .2,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Each tab owns a navigator, so horizontal paging preserves scroll and route state.
class SwipeTabPages extends StatefulWidget {
  const SwipeTabPages({required this.shell, required this.children, super.key});
  final StatefulNavigationShell shell;
  final List<Widget> children;
  @override
  State<SwipeTabPages> createState() => _SwipeTabPagesState();
}

class _SwipeTabPagesState extends State<SwipeTabPages> {
  late final PageController _pages = PageController(
    initialPage: widget.shell.currentIndex,
  );

  @override
  void didUpdateWidget(covariant SwipeTabPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Menu taps and deep links update the same selected branch as a swipe.
    if (_pages.hasClients &&
        _pages.page?.round() != widget.shell.currentIndex) {
      _pages.jumpToPage(widget.shell.currentIndex);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    key: const ValueKey('main-tab-pager'),
    controller: _pages,
    onPageChanged: (index) {
      if (index != widget.shell.currentIndex) widget.shell.goBranch(index);
    },
    children: [
      for (var i = 0; i < widget.children.length; i++)
        _KeptTab(
          key: ValueKey(i),
          child: TickerMode(
            enabled: i == widget.shell.currentIndex,
            child: widget.children[i],
          ),
        ),
    ],
  );
}

class _KeptTab extends StatefulWidget {
  const _KeptTab({required this.child, super.key});
  final Widget child;
  @override
  State<_KeptTab> createState() => _KeptTabState();
}

class _KeptTabState extends State<_KeptTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 28),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

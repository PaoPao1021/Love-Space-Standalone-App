import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.currentIndex, required this.child, super.key});

  final int currentIndex;
  final Widget child;

  static const _paths = ['/home', '/album', '/moments', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            border: Border.all(color: const Color(0x0F462D32)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12372328),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_paths.length, (index) {
              final active = index == currentIndex;
              const labels = ['首页', '相册', '点滴', '我的'];
              const symbols = ['⌂', '▧', '✦', '○'];
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: labels[index],
                  child: InkWell(
                    onTap: () => context.go(_paths[index]),
                    borderRadius: BorderRadius.circular(17),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 26,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text(
                                symbols[index],
                                style: TextStyle(
                                  fontSize: 23,
                                  height: 1,
                                  color: active
                                      ? const Color(0xFFE85D75)
                                      : const Color(0xFFAAA0A2),
                                ),
                              ),
                              if (active)
                                Positioned(
                                  right: -6,
                                  top: 1,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE85D75),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: .5,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? Theme.of(context).colorScheme.onSurface
                                : const Color(0xFFAAA0A2),
                          ),
                        ),
                      ],
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

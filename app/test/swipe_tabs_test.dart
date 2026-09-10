import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lovespace_app/features/shell/app_shell.dart';

void main() {
  testWidgets(
    'swipe, menu taps, boundaries, deep links and detail back share tab state',
    (tester) async {
      const paths = ['/home', '/album', '/moments', '/profile'];
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute(
            builder: (_, _, shell) => AppShell(
              currentIndex: shell.currentIndex,
              onSelect: (index) => shell.goBranch(index),
              child: shell,
            ),
            navigatorContainerBuilder: (_, shell, children) =>
                SwipeTabPages(shell: shell, children: children),
            branches: [
              for (var i = 0; i < 4; i++)
                StatefulShellBranch(
                  preload: true,
                  routes: [
                    GoRoute(
                      path: paths[i],
                      builder: (context, _) => ListView(
                        key: PageStorageKey('tab-$i'),
                        children: [
                          Text('content-$i'),
                          TextField(key: ValueKey('input-$i')),
                          TextButton(
                            onPressed: () => context.push('/detail'),
                            child: const Text('详情'),
                          ),
                          const SizedBox(height: 1600),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          GoRoute(
            path: '/detail',
            builder: (_, _) => const Scaffold(body: Text('detail')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final pager = find.byKey(const ValueKey('main-tab-pager'));
      await tester.enterText(find.byKey(const ValueKey('input-0')), '保留输入');
      FocusManager.instance.primaryFocus?.unfocus();
      for (var i = 1; i < 4; i++) {
        await tester.drag(pager, const Offset(-650, 0));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, paths[i]);
        expect(find.text('content-$i').hitTestable(), findsOneWidget);
      }
      await tester.drag(pager, const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(find.text('保留输入').hitTestable(), findsOneWidget);
      await tester.drag(pager, const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      await tester.drag(pager, const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      router.go('/moments');
      await tester.pumpAndSettle();
      expect(find.text('content-2').hitTestable(), findsOneWidget);
      await tester.tap(find.text('详情').hitTestable());
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('content-2').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

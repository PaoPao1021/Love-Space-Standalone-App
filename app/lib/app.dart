import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'core/push/push_client.dart';
import 'core/storage/account_cache.dart';
import 'features/anniversary/anniversary_page.dart';
import 'features/anniversary/anniversary_repository.dart';
import 'features/album/album_detail_page.dart';
import 'features/album/album_page.dart';
import 'features/album/album_repository.dart';
import 'features/auth/login_page.dart';
import 'features/auth/connect_page.dart';
import 'features/settings/settings_page.dart';
import 'theme/background_preferences.dart';
import 'features/home/home_page.dart';
import 'features/core_loop/core_loop_repository.dart';
import 'features/daily_question/daily_question_page.dart';
import 'features/mood/mood_page.dart';
import 'features/moments/moments_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';
import 'features/menu/menu_page.dart';
import 'features/memories/memories_repository.dart';
import 'features/points/points_page.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_page.dart';
import 'features/tasks/tasks_page.dart';
import 'features/together/together_hub_page.dart';
import 'features/together/together_repository.dart';
import 'features/wishes/wishes_page.dart';
import 'features/wellness/fitness_page.dart';
import 'features/wellness/monthly_report_page.dart';
import 'features/wellness/wellness_repository.dart';
import 'features/wellness/weekly_report_page.dart';
import 'features/quiz/quiz_page.dart';
import 'features/thanks/thanks_page.dart';
import 'features/timeline/timeline_page.dart';
import 'features/capsules/capsules_page.dart';
import 'theme/lovespace_theme.dart';

class LoveSpaceApp extends StatefulWidget {
  const LoveSpaceApp({
    required this.authController,
    required this.anniversaryRepository,
    required this.albumRepository,
    required this.coreLoopRepository,
    required this.togetherRepository,
    required this.memoriesRepository,
    required this.wellnessRepository,
    required this.accountCache,
    required this.pushClient,
    super.key,
  });

  final AuthController authController;
  final AnniversaryRepository anniversaryRepository;
  final AlbumRepository albumRepository;
  final CoreLoopRepository coreLoopRepository;
  final TogetherRepository togetherRepository;
  final MemoriesRepository memoriesRepository;
  final WellnessRepository wellnessRepository;
  final AccountCache accountCache;
  final PushClient pushClient;

  @override
  State<LoveSpaceApp> createState() => _LoveSpaceAppState();
}

class _LoveSpaceAppState extends State<LoveSpaceApp> {
  final _background = BackgroundPreferences();
  StreamSubscription<String>? _pushDeepLinkSubscription;

  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: widget.authController,
    redirect: (context, state) {
      final status = widget.authController.status;
      final path = state.matchedLocation;
      if (status == AuthStatus.booting) {
        return path == '/splash' ? null : '/splash';
      }
      if (status == AuthStatus.unauthenticated) {
        return path == '/login' ? null : '/login';
      }
      if (widget.authController.user?.coupleId.isEmpty == true) {
        return path == '/connect' ? null : '/connect';
      }
      if (path == '/connect') return '/home';
      if (path == '/login' || path == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        builder: (_, _) => ConnectPage(
          auth: widget.authController,
          repository: widget.coreLoopRepository,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsPage(
          auth: widget.authController,
          repository: widget.coreLoopRepository,
          background: _background,
        ),
      ),
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (_, _) => LoginPage(controller: widget.authController),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => AppShell(
          currentIndex: 0,
          child: HomePage(
            user: widget.authController.user,
            anniversaryRepository: widget.anniversaryRepository,
            coreLoopRepository: widget.coreLoopRepository,
          ),
        ),
      ),
      GoRoute(
        path: '/anniversaries',
        builder: (_, _) =>
            AnniversaryPage(repository: widget.anniversaryRepository),
      ),
      GoRoute(
        path: '/album',
        builder: (_, _) => AppShell(
          currentIndex: 1,
          child: AlbumPage(repository: widget.albumRepository),
        ),
      ),
      GoRoute(
        path: '/album/:albumId',
        builder: (_, state) => AlbumDetailPage(
          repository: widget.albumRepository,
          albumId: state.pathParameters['albumId']!,
          albumName: state.uri.queryParameters['name'] ?? '相册',
          uploadOnOpen: state.uri.queryParameters['upload'] == '1',
        ),
      ),
      GoRoute(
        path: '/moments',
        builder: (_, state) => AppShell(
          currentIndex: 2,
          child: MomentsPage(
            repository: widget.coreLoopRepository,
            cache: widget.accountCache,
            createOnOpen: state.uri.queryParameters['create'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/moments/:momentId',
        builder: (_, state) => AppShell(
          currentIndex: 2,
          child: MomentsPage(
            repository: widget.coreLoopRepository,
            cache: widget.accountCache,
            targetMomentId: state.pathParameters['momentId'],
          ),
        ),
      ),
      GoRoute(
        path: '/daily-question',
        builder: (_, _) => DailyQuestionPage(
          repository: widget.coreLoopRepository,
          cache: widget.accountCache,
        ),
      ),
      GoRoute(
        path: '/mood',
        builder: (_, _) => MoodPage(repository: widget.coreLoopRepository),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) =>
            NotificationsPage(repository: widget.coreLoopRepository),
      ),
      GoRoute(
        path: '/together',
        builder: (_, _) => AppShell(
          currentIndex: 3,
          child: TogetherHubPage(
            repository: widget.togetherRepository,
            memoriesRepository: widget.memoriesRepository,
            wellnessRepository: widget.wellnessRepository,
          ),
        ),
      ),
      GoRoute(
        path: '/tasks',
        builder: (_, _) => TasksPage(
          repository: widget.togetherRepository,
          userId: widget.authController.user!.id,
        ),
      ),
      GoRoute(
        path: '/tasks/:taskId',
        builder: (_, state) => TasksPage(
          repository: widget.togetherRepository,
          userId: widget.authController.user!.id,
          targetTaskId: state.pathParameters['taskId'],
        ),
      ),
      GoRoute(
        path: '/menu',
        builder: (_, _) => MenuPage(repository: widget.togetherRepository),
      ),
      GoRoute(
        path: '/points',
        builder: (_, _) => PointsPage(
          repository: widget.togetherRepository,
          userId: widget.authController.user!.id,
        ),
      ),
      GoRoute(
        path: '/wishes',
        builder: (_, _) => WishesPage(
          repository: widget.memoriesRepository,
          cache: widget.accountCache,
        ),
      ),
      GoRoute(
        path: '/wishes/:wishId',
        builder: (_, state) => WishesPage(
          repository: widget.memoriesRepository,
          cache: widget.accountCache,
          targetWishId: state.pathParameters['wishId'],
        ),
      ),
      GoRoute(
        path: '/capsules',
        builder: (_, _) => CapsulesPage(
          repository: widget.memoriesRepository,
          cache: widget.accountCache,
        ),
      ),
      GoRoute(
        path: '/capsules/:capsuleId',
        builder: (_, state) => CapsulesPage(
          repository: widget.memoriesRepository,
          cache: widget.accountCache,
          targetCapsuleId: state.pathParameters['capsuleId'],
        ),
      ),
      GoRoute(
        path: '/fitness',
        builder: (_, _) => FitnessPage(repository: widget.wellnessRepository),
      ),
      GoRoute(
        path: '/fitness-report',
        builder: (_, _) =>
            WeeklyReportPage(repository: widget.wellnessRepository),
      ),
      GoRoute(
        path: '/monthly-report',
        builder: (_, _) =>
            MonthlyReportPage(repository: widget.wellnessRepository),
      ),
      GoRoute(
        path: '/quiz',
        builder: (_, _) => QuizPage(repository: widget.coreLoopRepository),
      ),
      GoRoute(
        path: '/thanks',
        builder: (_, _) => ThanksPage(
          repository: widget.coreLoopRepository,
          cache: widget.accountCache,
        ),
      ),
      GoRoute(
        path: '/timeline',
        builder: (_, _) => TimelinePage(repository: widget.coreLoopRepository),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => AppShell(
          currentIndex: 3,
          child: ProfilePage(
            user: widget.authController.user!,
            authController: widget.authController,
            repository: widget.coreLoopRepository,
            cache: widget.accountCache,
            pushClient: widget.pushClient,
          ),
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_syncAppearance);
    _syncAppearance();
    _pushDeepLinkSubscription = widget.pushClient.deepLinks.listen(
      _openPushDeepLink,
    );
    widget.pushClient.startIfConsented();
  }

  void _syncAppearance() {
    final account = widget.authController.user?.id ?? '';
    widget.accountCache.scopeTo(account);
    _background.scopeTo(account, widget.accountCache);
  }

  void _openPushDeepLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.path.startsWith('/')) return;
    const allowed = [
      '/notifications',
      '/daily-question',
      '/moments',
      '/album',
      '/anniversaries',
      '/mood',
      '/tasks',
      '/menu',
      '/points',
      '/wishes',
      '/capsules',
      '/fitness',
      '/fitness-report',
      '/monthly-report',
      '/quiz',
      '/thanks',
      '/timeline',
    ];
    if (!allowed.any((prefix) => uri.path.startsWith(prefix))) return;
    _router.go(uri.toString());
  }

  @override
  void dispose() {
    widget.authController.removeListener(_syncAppearance);
    _background.dispose();
    _pushDeepLinkSubscription?.cancel();
    _router.dispose();
    widget.authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.user;
    if (user != null) widget.accountCache.scopeTo(user.id);
    return AnimatedBuilder(
      animation: _background,
      builder: (_, _) => MaterialApp.router(
        title: 'LoveSpace',
        debugShowCheckedModeBanner: false,
        theme: _background.image == null
            ? LoveSpaceTheme.light
            : LoveSpaceTheme.light.copyWith(
                scaffoldBackgroundColor: Colors.transparent,
              ),
        darkTheme: LoveSpaceTheme.dark,
        // The reference mini-program has a fixed cream canvas and light cards.
        themeMode: ThemeMode.light,
        routerConfig: _router,
        builder: (context, child) => DecoratedBox(
          decoration: const BoxDecoration(color: LoveSpaceColors.blush),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_background.image != null)
                Opacity(
                  opacity: _background.opacity,
                  child: Image.memory(_background.image!, fit: BoxFit.cover),
                ),
              child!,
            ],
          ),
        ),
      ),
    );
  }
}

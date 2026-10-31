import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/kitchen_provider.dart';
import 'providers/map_prefs_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'features/travel/travel_workspace.dart';
import 'providers/wardrobe_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/life/life_screen.dart';
import 'screens/memories/memories_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'features/travel/travel_screen.dart';
import 'screens/version/update_dialog.dart';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'utils/lovegirl_theme.dart';
import 'utils/app_section.dart';
import 'widgets/illus_image.dart';
import 'widgets/rebuild_controls.dart' show rebuildReduceMotion;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(LogService.init());
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const LoveGirlApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      NotificationService().init().catchError((Object error, StackTrace stack) {
        LogService().error('Notification', '初始化失败: $error', stack: stack);
      }),
    );
  });
}

class LoveGirlApp extends StatelessWidget {
  const LoveGirlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProxyProvider<AuthProvider, HomeProvider>(
          create: (_) => HomeProvider(),
          update: (_, auth, home) => home!..setAccount(auth.userId),
        ),
        ChangeNotifierProvider(create: (_) => KitchenProvider()),
        ChangeNotifierProvider(create: (_) => MapPrefsProvider()..load()),
        ChangeNotifierProxyProvider<AuthProvider, TravelWorkspace>(
          create: (_) => TravelWorkspace(),
          update: (_, auth, workspace) => workspace!..setAccount(auth.userId),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => WardrobeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                themeProvider.isDark ? Brightness.light : Brightness.dark,
          ));
          return MaterialApp(
            title: 'LoveGirl',
            scrollBehavior: const MaterialScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast)),
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh'),
            supportedLocales: const [Locale('zh'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: LoveGirlTheme.lightTheme,
            darkTheme: LoveGirlTheme.darkTheme,
            themeMode: themeProvider.mode,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const bool _skipVersionCheckInQa = bool.fromEnvironment(
    'LOVEGIRL_E2E_AUTO_LOGIN',
    defaultValue: false,
  );
  AppSection _section = AppSection.today;
  Timer? _versionCheckTimer;
  bool _versionCheckQueued = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _versionCheckTimer?.cancel();
    super.dispose();
  }

  void _navigateToTab(AppSection section) {
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    _syncVersionCheck(auth);

    if (auth.isInitializing) {
      return const _AppBootScreen();
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_section) {
      case AppSection.today:
        return HomeScreen(onNavigateToTab: _navigateToTab);
      case AppSection.memories:
        return const MemoriesScreen();
      case AppSection.travel:
        return const TravelScreen();
      case AppSection.life:
        return const LifeScreen();
      case AppSection.us:
        return const ProfileScreen();
    }
  }

  Widget _buildBottomNav() {
    const items = [
      _LoveNavItem('今天', Icons.calendar_today_outlined, Icons.calendar_today),
      _LoveNavItem('回忆', Icons.landscape_outlined, Icons.landscape_rounded),
      _LoveNavItem('旅行', Icons.location_on_outlined, Icons.location_on),
      _LoveNavItem('生活', Icons.eco_outlined, Icons.eco_outlined),
      _LoveNavItem('我们', Icons.people_outline_rounded, Icons.people_rounded),
    ];

    return SafeArea(
      top: false,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 74,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: context.lgPaper.withAlpha(235),
              border: Border(
                  top: BorderSide(color: context.lgSeparator.withAlpha(100))),
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _LoveBottomNavButton(
                      item: items[i],
                      selected: _section.index == i,
                      onTap: () => _navigateToTab(AppSection.values[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncVersionCheck(AuthProvider auth) {
    if (_skipVersionCheckInQa) {
      _versionCheckTimer?.cancel();
      _versionCheckTimer = null;
      _versionCheckQueued = false;
      return;
    }

    if (auth.isInitializing || !auth.isLoggedIn) {
      _versionCheckTimer?.cancel();
      _versionCheckTimer = null;
      _versionCheckQueued = false;
      return;
    }

    if (_versionCheckQueued) return;
    _versionCheckQueued = true;
    _versionCheckTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await checkVersionUpdate(context);
    });
  }
}

class _LoveNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _LoveNavItem(this.label, this.icon, this.activeIcon);
}

class _LoveBottomNavButton extends StatelessWidget {
  final _LoveNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _LoveBottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.lgInk : context.lgTextMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: 32,
        child: ExcludeSemantics(
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: rebuildReduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  scale: selected ? 1.06 : 1,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 25,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBootScreen extends StatelessWidget {
  const _AppBootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                color: context.lgPaperWarm,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: LoveGirlTheme.primary.withAlpha(10),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
                border: Border.all(
                  color: context.lgSeparator.withAlpha(140),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: IllusImg('ui_boot', height: 92)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: LoveGirlTheme.primary.withAlpha(16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: LoveGirlTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LoveGirl',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: context.lgTextPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '正在把今天的心意装进来',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.lgTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      backgroundColor: context.lgSeparator,
                      valueColor: AlwaysStoppedAnimation(LoveGirlTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '等一下下，专属票根和今天的安排马上就好。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: context.lgTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

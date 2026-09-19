import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/daily_provider.dart';
import 'providers/home_provider.dart';
import 'providers/kitchen_provider.dart';
import 'providers/map_prefs_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/travel_provider.dart';
import 'providers/tree_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/health/health_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/life/life_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/travel/travel_main_screen.dart';
import 'screens/version/update_dialog.dart';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'utils/lovegirl_theme.dart';

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
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => KitchenProvider()),
        ChangeNotifierProvider(create: (_) => MapPrefsProvider()..load()),
        ChangeNotifierProvider(create: (_) => TravelProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DailyProvider()),
        ChangeNotifierProvider(create: (_) => TreeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: themeProvider.isDark
                ? Brightness.light
                : Brightness.dark,
          ));
          return MaterialApp(
            title: 'LoveGirl',
          scrollBehavior: const MaterialScrollBehavior()
              .copyWith(physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast)),
            debugShowCheckedModeBanner: false,
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
  int _currentIndex = 0;
  int _lifeSubTab = 0;
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

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
      _lifeSubTab = 0;
    });
  }

  void _navigateToLifeSubTab(int subTab) {
    setState(() {
      _currentIndex = 3;
      _lifeSubTab = subTab;
    });
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
      bottomNavigationBar: _buildBottomNav(auth),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onNavigateToTab: _navigateToTab,
          onNavigateToSubTab: (tab, subTab) {
            if (tab == 3) {
              _navigateToLifeSubTab(subTab);
            } else {
              _navigateToTab(tab);
            }
          },
        );
      case 1:
        return const TravelMainScreen();
      case 2:
        return HealthScreen();
      case 3:
        return LifeScreen(
          key: ValueKey('life_$_lifeSubTab'),
          initialTab: _lifeSubTab,
        );
      case 4:
        return ProfileScreen(onNavigateToTab: _navigateToTab);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNav(AuthProvider auth) {
    void onTap(int index) {
      if (index == 2 && !auth.isGirl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('健康模块仅女友可用'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      setState(() => _currentIndex = index);
    }

    const items = [
      _LoveNavItem('首页', Icons.home_outlined, Icons.home_rounded),
      _LoveNavItem('旅行', Icons.map_outlined, Icons.map_rounded),
      _LoveNavItem('健康', Icons.favorite_border_rounded, Icons.favorite_rounded),
      _LoveNavItem('生活', Icons.grid_view_rounded, Icons.grid_view_rounded),
      _LoveNavItem('我的', Icons.person_outline_rounded, Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
        height: 74,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        decoration: BoxDecoration(
          color: context.lgPaper.withAlpha(216),
          border: const Border(
              top: BorderSide(color: Color(0x33FFFFFF), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _LoveBottomNavButton(
                  item: items[i],
                  selected: _currentIndex == i,
                  onTap: () => onTap(i),
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
    final color = selected ? LoveGirlTheme.primary : context.lgTextMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: selected ? 34 : 30,
                height: selected ? 30 : 28,
                decoration: BoxDecoration(
                  color: selected ? LoveGirlTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: selected ? 20 : 23,
                  color: selected ? Colors.white : color,
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
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
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

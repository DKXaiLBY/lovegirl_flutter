import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/travel_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/travel/travel_main_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/life/life_screen.dart';
import 'screens/health/health_screen.dart';
import 'screens/version/update_dialog.dart';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'utils/lovegirl_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.init(); // 加载持久化日志
  NotificationService().init(); // 初始化本地通知
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const LoveGirlApp());
}

class LoveGirlApp extends StatelessWidget {
  const LoveGirlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => TravelProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'LoveGirl',
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
  int _currentIndex = 0;
  int _lifeSubTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        checkVersionUpdate(context);
      }
    });
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

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    // 固定5个Tab：健康Tab对男友端显示但不允许进入
    // 旅行Tab使用懒加载，避免高德SDK在启动时初始化导致闪退
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onNavigateToTab: _navigateToTab,
            onNavigateToSubTab: (tab, subTab) {
              if (tab == 3) {
                _navigateToLifeSubTab(subTab);
              } else {
                _navigateToTab(tab);
              }
            },
          ),
          // 旅行Tab：懒加载，只在首次访问时创建
          _currentIndex == 1
              ? const TravelMainScreen()
              : const SizedBox.shrink(),
          const HealthScreen(),
          LifeScreen(key: ValueKey('life_$_lifeSubTab'), initialTab: _lifeSubTab),
          ProfileScreen(onNavigateToTab: _navigateToTab),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(auth),
    );
  }

  Widget _buildBottomNav(AuthProvider auth) {
    void onTap(int i) {
      // 健康Tab仅女友可用
      if (i == 2 && !auth.isGirl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('健康模块仅女友可用'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
        );
        return;
      }
      setState(() => _currentIndex = i);
    }

    return Container(
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        boxShadow: [
          BoxShadow(
            color: LoveGirlTheme.primary.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: LoveGirlTheme.primary,
        unselectedItemColor: LoveGirlTheme.textMuted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map_rounded), label: '旅行'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite_rounded), label: '健康'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), activeIcon: Icon(Icons.grid_view_rounded), label: '生活'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person_rounded), label: '我的'),
        ],
      ),
    );
  }
}

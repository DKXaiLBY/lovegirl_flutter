import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/providers/theme_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/services/log_service.dart';
import 'package:lovegirl_flutter/services/notification_service.dart';
import 'package:lovegirl_flutter/screens/version/update_dialog.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'log_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nicknameController;
  bool _isEditing = false;
  bool _isSaving = false;

  // 隐私开关（模拟后端状态）
  bool _photoVisible = true;
  bool _moodVisible = true;
  bool _travelVisible = true;
  bool _chatVisible = true;

  // 推送开关
  bool _pushEnabled = true;
  bool _pushPeriod = true;
  bool _pushAnniversary = true;
  bool _pushTodo = true;

  // 数据管理
  String _cacheSize = '计算中...';

  // 开发者模式 — 点击版本号7次开启
  int _devTapCount = 0;
  DateTime? _lastDevTapTime;
  bool _isDevMode = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        _nicknameController.text = auth.user?['nickname'] ?? '';
        _loadPrivacySettings();
        _loadPushSettings();
        _calculateCacheSize();
      }
    });
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final api = ApiService();
      final res = await api.getPrivacy();
      final data = res.data?['data'];
      if (data is Map) {
        if (mounted) {
          setState(() {
            _photoVisible = data['photo_visible'] != false;
            _moodVisible = data['mood_visible'] != false;
            _travelVisible = data['travel_visible'] != false;
            _chatVisible = data['chat_visible'] != false;
          });
        }
      }
      LogService().info('Settings', '隐私设置已加载');
    } catch (e) {
      LogService().error('Settings', '加载隐私设置失败: $e');
    }
  }

  Future<void> _loadPushSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _pushEnabled = prefs.getBool('push_enabled') ?? true;
          _pushPeriod = prefs.getBool('push_period') ?? true;
          _pushAnniversary = prefs.getBool('push_anniversary') ?? true;
          _pushTodo = prefs.getBool('push_todo') ?? true;
        });
      }
      LogService().info('Settings', '推送设置已加载');
    } catch (e) {
      LogService().error('Settings', '加载推送设置失败: $e');
    }
  }

  Future<void> _savePushSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      LogService().error('Settings', '保存推送设置失败: $e');
    }
  }

  Future<void> _calculateCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      int totalSize = 0;
      if (cacheDir.existsSync()) {
        final files = cacheDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            totalSize += file.lengthSync();
          }
        }
      }
      if (mounted) {
        setState(() {
          _cacheSize = _formatBytes(totalSize);
        });
      }
    } catch (e) {
      LogService().error('Settings', '计算缓存大小失败: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        for (final file in cacheDir.listSync(recursive: true)) {
          if (file is File) {
            try {
              file.deleteSync();
            } catch (_) {
              // 跳过被锁定的文件
            }
          }
        }
      }
      await _calculateCacheSize();
    } catch (e) {
      LogService().error('Settings', '清除缓存失败: $e');
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? LoveGirlTheme.bgDark : LoveGirlTheme.bgLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 14),
              _buildHeader(),
              const SizedBox(height: 22),
              _buildSectionHeader('编辑资料'),
              const SizedBox(height: 10),
              _buildProfileCard(auth),
              const SizedBox(height: 24),
              _buildSectionHeader('外观设置'),
              const SizedBox(height: 10),
              _buildThemeCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('旅行地图'),
              const SizedBox(height: 10),
              _buildMapCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('隐私安全'),
              const SizedBox(height: 10),
              _buildPrivacyCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('推送通知'),
              const SizedBox(height: 10),
              _buildPushCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('数据管理'),
              const SizedBox(height: 10),
              _buildDataCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('开发者'),
              const SizedBox(height: 10),
              _buildDevCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('关于'),
              const SizedBox(height: 10),
              _buildAboutCard(),
              const SizedBox(height: 24),
              _buildLogoutCard(auth),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LovePaper(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          LoveIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: '返回',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: LoveGirlTheme.secondarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.folder_special_rounded,
              color: LoveGirlTheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '资料夹管理',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '账号、安全、通知和数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: LoveGirlTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return LoveSectionTitle(title: title);
  }

  // ========== 编辑资料 ==========
  Widget _buildProfileCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _isEditing ? () => _changeAvatar() : null,
                child: Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: LoveGirlTheme.primary.withAlpha(50),
                              width: 2)),
                      child: ClipOval(
                        child: auth.user?['avatar'] != null &&
                                (auth.user!['avatar'] as String).isNotEmpty
                            ? Image.network(auth.user!['avatar'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarPlaceholder(auth))
                            : _avatarPlaceholder(auth),
                      ),
                    ),
                    if (_isEditing)
                      Positioned.fill(
                        child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.black38, shape: BoxShape.circle),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 22)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _isEditing
                    ? TextField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          hintText: '输入昵称',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: LoveGirlTheme.primary.withAlpha(60))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: LoveGirlTheme.primary)),
                        ),
                        style: const TextStyle(fontSize: 15),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.user?['nickname'] ?? '未设置',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: LoveGirlTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(auth.isGirl ? '女友' : '男友',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: LoveGirlTheme.textMuted)),
                        ],
                      ),
              ),
              GestureDetector(
                onTap: _isEditing
                    ? () => _saveProfile(auth)
                    : () => setState(() => _isEditing = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: (_isEditing
                              ? LoveGirlTheme.accent
                              : LoveGirlTheme.primary)
                          .withAlpha(25),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_isEditing ? '保存' : '编辑',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isEditing
                              ? LoveGirlTheme.accent
                              : LoveGirlTheme.primary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(AuthProvider auth) {
    final name = auth.user?['nickname'] ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: LoveGirlTheme.primary.withAlpha(30),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: LoveGirlTheme.primary,
          ),
        ),
      ),
    );
  }

  // ========== 主题 ==========
  Widget _buildThemeCard() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(Icons.light_mode_rounded, const Color(0xFFFFB300),
              '亮色模式', !isDark, (v) {
            if (v) themeProvider.setDarkMode(false);
          }),
          const Divider(height: 24, indent: 40),
          _buildSwitchRow(
              Icons.dark_mode_rounded, const Color(0xFF7C4DFF), '暗色模式', isDark,
              (v) {
            if (v) themeProvider.setDarkMode(true);
          }),
        ],
      ),
    );
  }

  // ========== 旅行地图 ==========
  Widget _buildMapCard() {
    final mapPrefs = context.watch<MapPrefsProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(
              Icons.route_rounded, LoveGirlTheme.primary, '顺序箭头连线',
              mapPrefs.showOrderArrows, (v) {
            mapPrefs.setShowOrderArrows(v);
          }),
          const Divider(height: 24, indent: 40),
          _buildSwitchRow(
              Icons.auto_awesome_rounded, LoveGirlTheme.secondary, '界面动效',
              mapPrefs.motionLevel != 'off', (v) {
            mapPrefs.setMotionLevel(v ? 'standard' : 'off');
          }),
        ],
      ),
    );
  }

  // ========== 隐私安全 ==========
  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(Icons.photo_library_outlined, LoveGirlTheme.primary,
              '相册可见', _photoVisible, (v) {
            setState(() => _photoVisible = v);
            ApiService().updatePrivacy({'photo_visible': v}).catchError((e) {
              LogService().error('Settings', '保存相册隐私失败: $e');
              if (mounted) {
                setState(() => _photoVisible = !v);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('保存失败，请重试'), duration: Duration(seconds: 1)));
              }
            });
            LogService().userAction('隐私:相册可见=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(
              Icons.mood_outlined, LoveGirlTheme.orange, '心情可见', _moodVisible,
              (v) {
            setState(() => _moodVisible = v);
            ApiService().updatePrivacy({'mood_visible': v}).catchError((e) {
              LogService().error('Settings', '保存心情隐私失败: $e');
              if (mounted) {
                setState(() => _moodVisible = !v);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('保存失败，请重试'), duration: Duration(seconds: 1)));
              }
            });
            LogService().userAction('隐私:心情可见=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(
              Icons.map_outlined, LoveGirlTheme.visited, '行程可见', _travelVisible,
              (v) {
            setState(() => _travelVisible = v);
            ApiService().updatePrivacy({'travel_visible': v}).catchError((e) {
              LogService().error('Settings', '保存行程隐私失败: $e');
              if (mounted) {
                setState(() => _travelVisible = !v);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('保存失败，请重试'), duration: Duration(seconds: 1)));
              }
            });
            LogService().userAction('隐私:行程可见=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.chat_bubble_outline, LoveGirlTheme.planned,
              '聊天记录可见', _chatVisible, (v) {
            setState(() => _chatVisible = v);
            ApiService().updatePrivacy({'chat_visible': v}).catchError((e) {
              LogService().error('Settings', '保存聊天隐私失败: $e');
              if (mounted) {
                setState(() => _chatVisible = !v);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('保存失败，请重试'), duration: Duration(seconds: 1)));
              }
            });
            LogService().userAction('隐私:聊天可见=$v');
          }),
        ],
      ),
    );
  }

  // ========== 推送设置 ==========
  Widget _buildPushCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(Icons.notifications_outlined, LoveGirlTheme.primary,
              '推送总开关', _pushEnabled, (v) {
            setState(() => _pushEnabled = v);
            _savePushSetting('push_enabled', v);
            NotificationService().setPushEnabled(v);
            LogService().userAction('推送:总开关=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.water_drop_outlined, LoveGirlTheme.pink, '姨妈提醒',
              _pushPeriod, (v) {
            setState(() => _pushPeriod = v);
            _savePushSetting('push_period', v);
            NotificationService.setPeriodEnabled(v);
            LogService().userAction('推送:姨妈提醒=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.favorite_outline, LoveGirlTheme.red, '纪念日提醒',
              _pushAnniversary, (v) {
            setState(() => _pushAnniversary = v);
            _savePushSetting('push_anniversary', v);
            NotificationService.setAnniversaryEnabled(v);
            LogService().userAction('推送:纪念日=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(
              Icons.checklist_outlined, LoveGirlTheme.accent, '待办提醒', _pushTodo,
              (v) {
            setState(() => _pushTodo = v);
            _savePushSetting('push_todo', v);
            NotificationService.setTodoEnabled(v);
            LogService().userAction('推送:待办=$v');
          }),
        ],
      ),
    );
  }

  // ========== 数据管理 ==========
  Widget _buildDataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildTapRow(Icons.cached_rounded, LoveGirlTheme.orange, '清除缓存',
              '当前 $_cacheSize', () async {
            await _clearCache();
            LogService().userAction('数据:清除缓存');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('缓存已清除'), duration: Duration(seconds: 1)));
            }
          }),
          const Divider(height: 20, indent: 40),
          _buildTapRow(Icons.file_download_outlined, LoveGirlTheme.primary,
              '导出数据', 'JSON格式', () {
            LogService().userAction('数据:导出');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('数据导出功能开发中'), duration: Duration(seconds: 1)));
          }),
          const Divider(height: 20, indent: 40),
          _buildTapRow(
              Icons.delete_sweep_outlined, LoveGirlTheme.red, '重置所有数据', '谨慎操作',
              () {
            _showResetConfirm();
          }),
        ],
      ),
    );
  }

  // ========== 开发者 ==========
  Widget _buildDevCard() {
    final auth = context.read<AuthProvider>();

    // 未开启开发者模式：仅显示日志入口
    if (!_isDevMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: _buildTapRow(Icons.bug_report_outlined, LoveGirlTheme.textMuted,
            '开发者日志', '查看API调用记录', () {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LogScreen()));
        }),
      );
    }

    // 开发者模式已开启
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                    color: LoveGirlTheme.orange,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('🔧 开发者模式',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: LoveGirlTheme.orange)),
            ],
          ),
          const SizedBox(height: 12),
          // 角色切换
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LoveGirlTheme.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: LoveGirlTheme.orange.withAlpha(40),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.swap_horiz_rounded,
                      color: LoveGirlTheme.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('角色切换',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: LoveGirlTheme.textPrimary)),
                      Text('调试用，翻转男/女友端视角',
                          style: TextStyle(
                              fontSize: 12, color: LoveGirlTheme.textMuted)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: auth.isDevRoleOverridden,
                  activeColor: LoveGirlTheme.orange,
                  onChanged: (v) {
                    if (v) {
                      auth.toggleDevRole();
                    } else {
                      auth.resetDevRole();
                    }
                    setState(() {});
                    LogService()
                        .userAction('开发者:角色切换 -> ${auth.isGirl ? "女友" : "男友"}');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前视角: ${auth.isGirl ? "👧 女友端" : "👦 男友端"}${auth.isDevRoleOverridden ? " (已覆盖)" : ""}',
            style: TextStyle(
                fontSize: 13,
                color: auth.isDevRoleOverridden
                    ? LoveGirlTheme.orange
                    : LoveGirlTheme.textMuted),
          ),
          const Divider(height: 24, indent: 40),
          _buildTapRow(Icons.bug_report_outlined, LoveGirlTheme.textMuted,
              '开发者日志', '查看API/错误记录', () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => const LogScreen()));
          }),
        ],
      ),
    );
  }

  void _onVersionTap() {
    final now = DateTime.now();
    // 超过3秒重置计数
    if (_lastDevTapTime != null &&
        now.difference(_lastDevTapTime!).inSeconds > 3) {
      _devTapCount = 0;
    }
    _lastDevTapTime = now;
    _devTapCount++;

    if (_devTapCount >= 7 && !_isDevMode) {
      setState(() => _isDevMode = true);
      _devTapCount = 0;
      LogService().userAction('开发者模式:已开启');
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔧 开发者模式已开启'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } else if (_devTapCount >= 5 && !_isDevMode) {
      // 5次时给提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('再点击 ${7 - _devTapCount} 次开启开发者模式'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // ========== 关于 ==========
  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildInfoRow(Icons.info_outline, '应用名称', AppConstants.appName),
          const Divider(height: 24, indent: 40),
          // 版本号 — 可点击（7次连击开启开发者模式）
          GestureDetector(
            onTap: _onVersionTap,
            child: _buildInfoRow(Icons.tag, '当前版本',
                'v${AppConstants.versionName} (build ${AppConstants.versionCode})'),
          ),
          const Divider(height: 24, indent: 40),
          _buildTapRow(Icons.system_update_outlined, LoveGirlTheme.accent,
              '检查更新', '点击检查', () {
            manualCheckVersion(context);
          }),
          const Divider(height: 24, indent: 40),
          _buildInfoRow(Icons.favorite_outline, '用心打造', '给最爱的你 💕'),
        ],
      ),
    );
  }

  // ========== 退出登录 ==========
  Widget _buildLogoutCard(AuthProvider auth) {
    return GestureDetector(
      onTap: () => _showLogoutConfirm(auth),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _cardDeco(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout,
                size: 20, color: LoveGirlTheme.pink.withAlpha(200)),
            const SizedBox(width: 8),
            Text('退出登录',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.pink.withAlpha(220))),
          ],
        ),
      ),
    );
  }

  // ========== 工具组件 ==========
  BoxDecoration _cardDeco() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? LoveGirlTheme.cardDark : LoveGirlTheme.paper,
      borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(18) : LoveGirlTheme.separator,
      ),
      boxShadow: isDark ? null : LoveGirlTheme.cardShadow(),
    );
  }

  Widget _buildSwitchRow(IconData icon, Color iconColor, String label,
      bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: LoveGirlTheme.textPrimary))),
        Switch.adaptive(
            value: value,
            activeColor: LoveGirlTheme.primary,
            onChanged: onChanged),
      ],
    );
  }

  Widget _buildTapRow(IconData icon, Color iconColor, String label,
      String trailing, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: LoveGirlTheme.textPrimary))),
          Text(trailing,
              style: const TextStyle(
                  fontSize: 13, color: LoveGirlTheme.textMuted)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 18, color: LoveGirlTheme.textMuted),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isHeartRow = icon == Icons.favorite_outline;
    return Row(
      children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: (isHeartRow ? LoveGirlTheme.pink : LoveGirlTheme.primary)
                    .withAlpha(isHeartRow ? 25 : 20),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon,
                color: isHeartRow ? LoveGirlTheme.pink : LoveGirlTheme.primary,
                size: 20)),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontSize: 15, color: LoveGirlTheme.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: LoveGirlTheme.textPrimary)),
      ],
    );
  }

  // ========== 操作方法 ==========
  void _changeAvatar() {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
            color: LoveGirlTheme.cardLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('更换头像',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: LoveGirlTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_outlined,
                      color: LoveGirlTheme.primary)),
              title: const Text('从相册选择'),
              trailing: const Icon(Icons.chevron_right,
                  color: LoveGirlTheme.textMuted),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 85);
                  if (file != null) {
                    LogService().userAction('头像:选择图片 ${file.path}');
                    _uploadAvatar(file.path);
                  }
                } catch (e) {
                  LogService().error('Settings', '选择图片失败: $e');
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: LoveGirlTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: LoveGirlTheme.primary)),
              title: const Text('拍照'),
              trailing: const Icon(Icons.chevron_right,
                  color: LoveGirlTheme.textMuted),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final file = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 85);
                  if (file != null) {
                    LogService().userAction('头像:拍照 ${file.path}');
                    _uploadAvatar(file.path);
                  }
                } catch (e) {
                  LogService().error('Settings', '拍照失败: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatar(String filePath) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final api = ApiService();
      final res = await api.uploadAvatar(filePath);
      final data = res.data?['data'];
      final avatarUrl = data is Map ? (data['url'] ?? '') : '';
      if (avatarUrl.isNotEmpty && mounted) {
        final auth = context.read<AuthProvider>();
        await auth.updateProfile({'avatar': avatarUrl});
      }
      LogService().userAction('头像:上传成功');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('头像已更新'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      LogService().error('Settings', '头像上传失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('上传失败，请重试'), behavior: SnackBarBehavior.floating),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    if (_isSaving) return;
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('昵称不能为空')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await auth.updateProfile({'nickname': newNickname});
      LogService().userAction('昵称修改: $newNickname');
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存成功')));
      }
    } catch (e) {
      LogService().error('Settings', '保存昵称失败: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('确认重置', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('将清除所有本地数据，包括缓存和登录状态。此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LogService().userAction('数据:确认重置');
              final auth = context.read<AuthProvider>();
              auth.logout();
            },
            child: Text('确认重置',
                style: TextStyle(color: LoveGirlTheme.red.withAlpha(220))),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? LoveGirlTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('确认退出', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('退出后需要重新登录哦~'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              auth.logout();
              LogService().userAction('退出登录');
            },
            child: Text('退出',
                style: TextStyle(color: LoveGirlTheme.pink.withAlpha(220))),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/theme_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:lovegirl_flutter/services/log_service.dart';
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
  String _cacheSize = '12.8 MB';

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        _nicknameController.text = auth.user?['nickname'] ?? '';
        _loadPrivacySettings();
      }
    });
  }

  Future<void> _loadPrivacySettings() async {
    // TODO: 从后端加载隐私设置
    LogService().info('Settings', '加载隐私/推送设置');
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
      appBar: AppBar(
        title: const Text('设置'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildSectionHeader('编辑资料'),
            const SizedBox(height: 10),
            _buildProfileCard(auth),
            const SizedBox(height: 24),
            _buildSectionHeader('外观设置'),
            const SizedBox(height: 10),
            _buildThemeCard(),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: LoveGirlTheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
        ],
      ),
    );
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
                      width: 64, height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: LoveGirlTheme.primary.withAlpha(50), width: 2)),
                      child: ClipOval(
                        child: auth.user?['avatar'] != null && (auth.user!['avatar'] as String).isNotEmpty
                            ? Image.network(auth.user!['avatar'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarPlaceholder(auth))
                            : _avatarPlaceholder(auth),
                      ),
                    ),
                    if (_isEditing)
                      Positioned.fill(
                        child: Container(decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.white, size: 22)),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LoveGirlTheme.primary.withAlpha(60))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LoveGirlTheme.primary)),
                        ),
                        style: const TextStyle(fontSize: 15),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.user?['nickname'] ?? '未设置', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LoveGirlTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(auth.isGirl ? '女友' : '男友', style: const TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
                        ],
                      ),
              ),
              GestureDetector(
                onTap: _isEditing ? () => _saveProfile(auth) : () => setState(() => _isEditing = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: (_isEditing ? LoveGirlTheme.accent : LoveGirlTheme.primary).withAlpha(25), borderRadius: BorderRadius.circular(10)),
                  child: Text(_isEditing ? '保存' : '编辑', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isEditing ? LoveGirlTheme.accent : LoveGirlTheme.primary)),
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
    return Container(color: LoveGirlTheme.primary.withAlpha(30), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: LoveGirlTheme.primary))));
  }

  // ========== 主题 ==========
  Widget _buildThemeCard() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    return Container(
      padding: const EdgeInsets.all(16), decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(Icons.light_mode_rounded, const Color(0xFFFFB300), '亮色模式', !isDark, (v) { if (v) themeProvider.setDarkMode(false); }),
          const Divider(height: 24, indent: 40),
          _buildSwitchRow(Icons.dark_mode_rounded, const Color(0xFF7C4DFF), '暗色模式', isDark, (v) { if (v) themeProvider.setDarkMode(true); }),
        ],
      ),
    );
  }

  // ========== 隐私安全 ==========
  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(16), decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(Icons.photo_library_outlined, LoveGirlTheme.primary, '相册可见', _photoVisible, (v) {
            setState(() => _photoVisible = v);
            LogService().userAction('隐私:相册可见=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.mood_outlined, LoveGirlTheme.orange, '心情可见', _moodVisible, (v) {
            setState(() => _moodVisible = v);
            LogService().userAction('隐私:心情可见=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.map_outlined, LoveGirlTheme.visited, '行程可见', _travelVisible, (v) {
            setState(() => _travelVisible = v);
            LogService().userAction('隐私:行程可见=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.chat_bubble_outline, LoveGirlTheme.planned, '聊天记录可见', _chatVisible, (v) {
            setState(() => _chatVisible = v);
            LogService().userAction('隐私:聊天可见=$v');
          }),
        ],
      ),
    );
  }

  // ========== 推送设置 ==========
  Widget _buildPushCard() {
    return Container(
      padding: const EdgeInsets.all(16), decoration: _cardDeco(),
      child: Column(
        children: [
          _buildSwitchRow(Icons.notifications_outlined, LoveGirlTheme.primary, '推送总开关', _pushEnabled, (v) {
            setState(() => _pushEnabled = v);
            LogService().userAction('推送:总开关=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.water_drop_outlined, LoveGirlTheme.pink, '姨妈提醒', _pushPeriod, (v) {
            setState(() => _pushPeriod = v);
            LogService().userAction('推送:姨妈提醒=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.favorite_outline, LoveGirlTheme.red, '纪念日提醒', _pushAnniversary, (v) {
            setState(() => _pushAnniversary = v);
            LogService().userAction('推送:纪念日=$v');
          }),
          const Divider(height: 20, indent: 40),
          _buildSwitchRow(Icons.checklist_outlined, LoveGirlTheme.accent, '待办提醒', _pushTodo, (v) {
            setState(() => _pushTodo = v);
            LogService().userAction('推送:待办=$v');
          }),
        ],
      ),
    );
  }

  // ========== 数据管理 ==========
  Widget _buildDataCard() {
    return Container(
      padding: const EdgeInsets.all(16), decoration: _cardDeco(),
      child: Column(
        children: [
          _buildTapRow(Icons.cached_rounded, LoveGirlTheme.orange, '清除缓存', '当前 $_cacheSize', () {
            setState(() => _cacheSize = '0 B');
            LogService().userAction('数据:清除缓存');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除'), duration: Duration(seconds: 1)));
          }),
          const Divider(height: 20, indent: 40),
          _buildTapRow(Icons.file_download_outlined, LoveGirlTheme.primary, '导出数据', 'JSON格式', () {
            LogService().userAction('数据:导出');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据导出功能开发中'), duration: Duration(seconds: 1)));
          }),
          const Divider(height: 20, indent: 40),
          _buildTapRow(Icons.delete_sweep_outlined, LoveGirlTheme.red, '重置所有数据', '谨慎操作', () {
            _showResetConfirm();
          }),
        ],
      ),
    );
  }

  // ========== 开发者 ==========
  Widget _buildDevCard() {
    return Container(
      padding: const EdgeInsets.all(16), decoration: _cardDeco(),
      child: _buildTapRow(Icons.bug_report_outlined, LoveGirlTheme.textMuted, '开发者日志', '查看API调用记录', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LogScreen()));
      }),
    );
  }

  // ========== 关于 ==========
  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16), decoration: _cardDeco(),
      child: Column(
        children: [
          _buildInfoRow(Icons.info_outline, '应用名称', AppConstants.appName),
          const Divider(height: 24, indent: 40),
          _buildInfoRow(Icons.tag, '版本号', 'v${AppConstants.versionName} (build ${AppConstants.versionCode})'),
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
            Icon(Icons.logout, size: 20, color: LoveGirlTheme.pink.withAlpha(200)),
            const SizedBox(width: 8),
            Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LoveGirlTheme.pink.withAlpha(220))),
          ],
        ),
      ),
    );
  }

  // ========== 工具组件 ==========
  BoxDecoration _cardDeco() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LoveGirlTheme.glassDecoration(tint: isDark ? LoveGirlTheme.cardDark : Colors.white, opacity: isDark ? 0.5 : 0.85);
  }

  Widget _buildSwitchRow(IconData icon, Color iconColor, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary))),
        Switch.adaptive(value: value, activeColor: LoveGirlTheme.primary, onChanged: onChanged),
      ],
    );
  }

  Widget _buildTapRow(IconData icon, Color iconColor, String label, String trailing, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: LoveGirlTheme.textPrimary))),
          Text(trailing, style: const TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: LoveGirlTheme.textMuted),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isHeartRow = icon == Icons.favorite_outline;
    return Row(
      children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: (isHeartRow ? LoveGirlTheme.pink : LoveGirlTheme.primary).withAlpha(isHeartRow ? 25 : 20), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: isHeartRow ? LoveGirlTheme.pink : LoveGirlTheme.primary, size: 20)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 15, color: LoveGirlTheme.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary)),
      ],
    );
  }

  // ========== 操作方法 ==========
  void _changeAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(color: LoveGirlTheme.cardLight, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('更换头像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: LoveGirlTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.photo_library_outlined, color: LoveGirlTheme.primary)),
              title: const Text('从相册选择'),
              trailing: const Icon(Icons.chevron_right, color: LoveGirlTheme.textMuted),
              onTap: () {
                Navigator.pop(ctx);
                LogService().userAction('头像:从相册选择');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await auth.updateProfile({'nickname': newNickname});
      LogService().userAction('昵称修改: $newNickname');
      setState(() { _isEditing = false; _isSaving = false; });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
    } catch (e) {
      LogService().error('Settings', '保存昵称失败: $e');
      setState(() => _isSaving = false);
    }
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认重置', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('将清除所有本地数据，包括缓存和登录状态。此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LogService().userAction('数据:确认重置');
              final auth = context.read<AuthProvider>();
              auth.logout();
            },
            child: Text('确认重置', style: TextStyle(color: LoveGirlTheme.red.withAlpha(220))),
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
        title: const Text('确认退出', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('退出后需要重新登录哦~'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              auth.logout();
              LogService().userAction('退出登录');
            },
            child: Text('退出', style: TextStyle(color: LoveGirlTheme.pink.withAlpha(220))),
          ),
        ],
      ),
    );
  }
}

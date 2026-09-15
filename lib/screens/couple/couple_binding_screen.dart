import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';

/// 伴侣绑定页面
class CoupleBindingScreen extends StatefulWidget {
  const CoupleBindingScreen({super.key});

  @override
  State<CoupleBindingScreen> createState() => _CoupleBindingScreenState();
}

class _CoupleBindingScreenState extends State<CoupleBindingScreen> {
  final ApiService _api = ApiService();
  final _codeController = TextEditingController();

  bool _loading = true;
  bool _coupled = false;
  Map<String, dynamic>? _partner;
  String? _coupledAt;

  // 邀请码状态
  String? _inviteCode;
  int _expiresIn = 0;
  Timer? _countdownTimer;
  bool _generating = false;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCoupleStatus();
      final data = res.data?['data'];
      if (data is Map) {
        setState(() {
          _coupled = data['coupled'] == true;
          _partner = data['partner'];
          _coupledAt = data['coupled_at']?.toString();
        });
      }
    } catch (e) {
      LogService().error('Couple', '查询绑定状态失败: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _generateInvite() async {
    setState(() => _generating = true);
    try {
      final res = await _api.createCoupleInvite();
      final data = res.data?['data'];
      if (data is Map) {
        setState(() {
          _inviteCode = data['invite_code'];
          _expiresIn = data['expires_in'] ?? 600;
        });
        _startCountdown();
        LogService().userAction('伴侣:生成邀请码');
      }
    } catch (e) {
      LogService().error('Couple', '生成邀请码失败: $e');
      if (mounted) {
        final msg = e.toString().contains('已经绑定') ? '你已经绑定过了' : '生成失败，请重试';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    }
    setState(() => _generating = false);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiresIn <= 0) {
        timer.cancel();
        setState(() => _inviteCode = null);
      } else {
        setState(() => _expiresIn--);
      }
    });
  }

  Future<void> _acceptInvite() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入6位邀请码'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _accepting = true);
    try {
      await _api.acceptCoupleInvite(code);
      LogService().userAction('伴侣:绑定成功');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('绑定成功！'), behavior: SnackBarBehavior.floating),
        );
      }
      await _loadStatus();
    } catch (e) {
      LogService().error('Couple', '绑定失败: $e');
      if (mounted) {
        String msg = '绑定失败';
        if (e.toString().contains('无效')) msg = '邀请码无效或已使用';
        if (e.toString().contains('过期')) msg = '邀请码已过期，请让对方重新生成';
        if (e.toString().contains('自己')) msg = '不能和自己绑定哦';
        if (e.toString().contains('已经绑定')) msg = '你已经绑定过了';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    }
    setState(() => _accepting = false);
  }

  Future<void> _breakCouple() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('解除绑定'),
        content: const Text('确定要解除与TA的绑定关系吗？\n解除后，隐私设置和投喂站将受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('确认解绑', style: TextStyle(color: LoveGirlTheme.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.breakCouple();
        LogService().userAction('伴侣:解绑');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('已解除绑定'), behavior: SnackBarBehavior.floating),
          );
        }
        setState(() {
          _coupled = false;
          _partner = null;
          _inviteCode = null;
        });
      } catch (e) {
        LogService().error('Couple', '解绑失败: $e');
      }
    }
  }

  String _formatExpires(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _buildHeader(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _coupled
                      ? _buildCoupledView()
                      : _buildUnboundView(),
            ),
          ],
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
              color: LoveGirlTheme.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.link_rounded,
              color: LoveGirlTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '伴侣绑定',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '把这份 App 连接成两个人的',
                  style: TextStyle(
                    fontSize: 12,
                    color: LoveGirlTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          LovePill(
            text: _coupled ? '已连接' : '未绑定',
            color: _coupled ? LoveGirlTheme.secondary : LoveGirlTheme.primary,
          ),
        ],
      ),
    );
  }

  // ==================== 已绑定视图 ====================
  Widget _buildCoupledView() {
    final partner = _partner ?? {};
    final nickname = partner['nickname'] ?? 'TA';
    final role = partner['role'] == 'girl' ? '👧 女友' : '👦 男友';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 绑定成功卡片
        LoveTicketCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // 双头像
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatar('我', LoveGirlTheme.primary),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.favorite_rounded,
                        color: LoveGirlTheme.primary, size: 32),
                  ),
                  _buildAvatar(nickname, LoveGirlTheme.secondary),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '$nickname · $role',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: LoveGirlTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '已绑定${_coupledAt != null ? " · ${_coupledAt!.substring(0, 10)}" : ""}',
                style: const TextStyle(
                    fontSize: 14, color: LoveGirlTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 功能说明
        LovePaper(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('绑定后可以',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildFeatureItem(
                  Icons.photo_library_outlined, '隐私设置互查', '查看对方是否允许访问相册、心情等'),
              _buildFeatureItem(Icons.card_giftcard, '投喂站互送', '自动识别伴侣，无需手动选择'),
              _buildFeatureItem(
                  Icons.chat_bubble_outline, '专属聊天', '只有你们两个人的私密空间'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 解绑按钮
        GestureDetector(
          onTap: _breakCouple,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
              border: Border.all(color: LoveGirlTheme.red.withAlpha(100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link_off,
                    size: 18, color: LoveGirlTheme.red.withAlpha(200)),
                const SizedBox(width: 8),
                Text('解除绑定',
                    style: TextStyle(
                        fontSize: 15, color: LoveGirlTheme.red.withAlpha(200))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 未绑定视图 ====================
  Widget _buildUnboundView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 说明
        LovePaper(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: LoveGirlTheme.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: LoveGirlTheme.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('绑定你的另一半',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '绑定后可以享受完整的功能体验',
                style: TextStyle(fontSize: 14, color: LoveGirlTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 方式一：生成邀请码
        _buildSectionTitle('方式一：邀请对方绑定'),
        const SizedBox(height: 12),
        LovePaper(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_inviteCode == null) ...[
                const Text('生成一个6位邀请码，发给TA输入即可',
                    style: TextStyle(
                        fontSize: 13, color: LoveGirlTheme.textMuted)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _generateInvite,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.qr_code_rounded),
                    label: const Text('生成邀请码'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LoveGirlTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ] else ...[
                const Text('请将此邀请码发给TA',
                    style: TextStyle(
                        fontSize: 13, color: LoveGirlTheme.textMuted)),
                const SizedBox(height: 16),
                // 邀请码展示
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _inviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('已复制'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: LoveGirlTheme.primaryLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _inviteCode!,
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: LoveGirlTheme.primary,
                              letterSpacing: 12,
                              fontFamily: 'monospace'),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.copy_rounded,
                            color: LoveGirlTheme.primary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '有效期 ${_formatExpires(_expiresIn)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: _expiresIn < 60
                          ? LoveGirlTheme.red
                          : LoveGirlTheme.textMuted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _generating ? null : _generateInvite,
                  child: const Text('重新生成'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 方式二：输入邀请码
        _buildSectionTitle('方式二：输入对方的邀请码'),
        const SizedBox(height: 12),
        LovePaper(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                      fontSize: 28,
                      color: LoveGirlTheme.textMuted.withAlpha(80),
                      letterSpacing: 12,
                      fontFamily: 'monospace'),
                  counterText: '',
                  filled: true,
                  fillColor: LoveGirlTheme.bgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _accepting ? null : _acceptInvite,
                  icon: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link_rounded),
                  label: const Text('立即绑定'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LoveGirlTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(60),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: LoveGirlTheme.primary,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LoveGirlTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: LoveGirlTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: LoveGirlTheme.textSecondary),
                children: [
                  TextSpan(
                      text: title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: LoveGirlTheme.textPrimary)),
                  const TextSpan(text: '  '),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

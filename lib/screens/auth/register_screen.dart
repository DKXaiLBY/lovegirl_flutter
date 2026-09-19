import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _gender = 'female';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _nicknameController.text.trim(),
      gender: _gender,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // 注册成功自动登录，pop 回 AppShell，此时 isLoggedIn=true 自动切到主页
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6B8A),
              Color(0xFFFF8FA8),
              Color(0xFFFFB347),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildAppBar(),
                  const SizedBox(height: 12),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildRegisterCard(),
                  const SizedBox(height: 24),
                  _buildLoginLink(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          '创建账号',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '加入 LoveGirl，开始记录你们的爱情',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withAlpha(190),
            fontWeight: FontWeight.w300,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '填写信息',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.lgTextPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 24),

            // 用户名
            _buildInputField(
              controller: _usernameController,
              hint: '用户名',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入用户名';
                if (v.trim().length < 2) return '用户名至少2个字符';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 昵称
            _buildInputField(
              controller: _nicknameController,
              hint: '昵称',
              icon: Icons.face_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入昵称';
                if (v.trim().length > 20) return '昵称不能超过20个字符';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 密码
            _buildGenderSelector(),
            const SizedBox(height: 16),

            _buildInputField(
              controller: _passwordController,
              hint: '密码',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: context.lgTextMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入密码';
                if (v.length < 6) return '密码至少6个字符';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 确认密码
            _buildInputField(
              controller: _confirmPasswordController,
              hint: '确认密码',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureConfirm,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: context.lgTextMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '请确认密码';
                if (v != _passwordController.text) return '两次密码不一致';
                return null;
              },
            ),
            SizedBox(height: 28),

            // 注册按钮
            SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B8A), Color(0xFFFF8FA8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B8A).withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '注  册',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        fontSize: 17,
        color: context.lgTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: context.lgTextMuted.withAlpha(160),
          fontSize: 15,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(icon, color: context.lgTextMuted, size: 22),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: context.lgBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: context.lgInk,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderSelector() {
    Widget option(String gender, String label, IconData icon) {
      final selected = _gender == gender;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _gender = gender),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? context.lgInk.withAlpha(24)
                  : context.lgBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? LoveGirlTheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? context.lgInk
                      : context.lgTextMuted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? context.lgInk
                          : context.lgTextPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('female', '女生', Icons.female_rounded),
        const SizedBox(width: 12),
        option('male', '男生', Icons.male_rounded),
      ],
    );
  }

  Widget _buildLoginLink() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withAlpha(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: Colors.white.withAlpha(210),
            ),
            const SizedBox(width: 4),
            Text(
              '已有账号？',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(210),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '返回登录',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

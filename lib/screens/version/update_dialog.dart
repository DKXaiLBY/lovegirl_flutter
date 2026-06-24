import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';

/// 存储已忽略版本的 key
const _kIgnoredVersionKey = 'ignored_update_version';

/// 显示版本更新弹窗
Future<void> showUpdateDialog(
  BuildContext context,
  Map<String, dynamic> data, {
  bool forceUpdate = false,
}) async {
  final version = data['version'] as Map<String, dynamic>? ?? {};
  final changelog = (version['changelog'] ?? '').toString();
  final latestVersionName = (version['name'] ?? '').toString();
  final latestVersionCode = version['code'] ?? 0;
  final url = (version['url'] ?? '').toString();
  final currentVersionLabel =
      'v${AppConstants.versionName} (build ${AppConstants.versionCode})';

  // 解析 changelog 为条目列表
  final changelogLines = changelog
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // 构造完整下载 URL
  final downloadUrl = url.startsWith('http')
      ? url
      : '${AppConstants.baseUrl}$url';

  return showDialog(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (ctx) => PopScope(
      canPop: !forceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: LoveGirlTheme.cardLight,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== 头部 =====
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  children: [
                    // 图标
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: LoveGirlTheme.gradientLove,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: LoveGirlTheme.primary.withAlpha(60),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '发现新版本',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 版本对比
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.bgLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentVersionLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: LoveGirlTheme.textMuted,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 18, color: LoveGirlTheme.primary),
                          ),
                          Text(
                            'v$latestVersionName',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: LoveGirlTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===== 更新日志 =====
              if (changelogLines.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.bgLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 16, color: LoveGirlTheme.primary),
                          SizedBox(width: 6),
                          Text(
                            '更新内容',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: LoveGirlTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...changelogLines.map((line) {
                        final isBullet = line.startsWith(RegExp(r'^[-•·✨🆕✅🌤🔧💾⬇️🎨🐛📊💕🎉]'));
                        final text = isBullet
                            ? line.replaceFirst(RegExp(r'^[-•·]\s*'), '')
                            : line;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isBullet) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: LoveGirlTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isBullet
                                        ? LoveGirlTheme.textPrimary
                                        : LoveGirlTheme.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              // ===== 按钮区域 =====
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    // 立即更新按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _downloadAndUpdate(context, downloadUrl);
                          LogService().userAction(
                              '版本更新:下载 $currentVersionLabel → v$latestVersionName');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LoveGirlTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '立即更新',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    // 稍后再说（非强制更新时显示）
                    if (!forceUpdate) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () async {
                            // 记住用户跳过了这个版本
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString(
                                _kIgnoredVersionKey, latestVersionName);
                            Navigator.pop(ctx);
                            LogService().userAction(
                                '版本更新:跳过 v$latestVersionName');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: LoveGirlTheme.textMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '跳过此版本',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 下载并安装更新
Future<void> _downloadAndUpdate(
    BuildContext context, String downloadUrl) async {
  try {
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // 备用：用浏览器打开
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (e) {
    LogService().error('Version', '下载更新失败: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('下载失败，请检查网络后重试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// 检查版本更新（启动时自动检查）
Future<void> checkVersionUpdate(BuildContext context) async {
  await _doCheck(context, silent: true);
}

/// 手动检查版本更新
Future<void> manualCheckVersion(BuildContext context) async {
  await _doCheck(context, silent: false);
}

Future<void> _doCheck(BuildContext context, {required bool silent}) async {
  try {
    final res = await ApiService().checkVersion(AppConstants.versionCode);
    final data = res.data?['data'];
    final hasUpdate = data != null && data['hasUpdate'] == true;

    if (hasUpdate) {
      final version = data['version'] as Map<String, dynamic>? ?? {};
      final latestVersionName = (version['name'] ?? '').toString();

      // 检查用户是否跳过了这个版本（手动检查时忽略跳过）
      if (silent) {
        final prefs = await SharedPreferences.getInstance();
        final ignoredVersion = prefs.getString(_kIgnoredVersionKey);
        if (ignoredVersion == latestVersionName) {
          LogService().info(
              'Version', '用户跳过了 v$latestVersionName，不弹窗');
          return;
        }
      }

      if (context.mounted) {
        showUpdateDialog(context, data!,
            forceUpdate: data['needUpdate'] == true);
      }
    } else if (!silent) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '当前已是最新版本 v${AppConstants.versionName}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    LogService().info('Version',
        '版本检查完成(${silent ? "自动" : "手动"}): 当前=v${AppConstants.versionName} build${AppConstants.versionCode}, 有更新=$hasUpdate');
  } catch (e) {
    LogService().error('Version', '版本检查失败: $e');
    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('检查更新失败，请检查网络连接'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

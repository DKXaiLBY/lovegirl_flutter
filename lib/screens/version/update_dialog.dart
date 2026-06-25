import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
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
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: LoveGirlTheme.cardLight,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== 头部（固定）=====
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    // 图标
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: LoveGirlTheme.gradientLove,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: LoveGirlTheme.primary.withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '发现新版本',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 版本对比
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.bgLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentVersionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LoveGirlTheme.textMuted,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 16, color: LoveGirlTheme.primary),
                          ),
                          Text(
                            'v$latestVersionName',
                            style: const TextStyle(
                              fontSize: 13,
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

              // ===== 更新日志（可滚动）=====
              if (changelogLines.isNotEmpty)
                Flexible(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.bgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 15, color: LoveGirlTheme.primary),
                            SizedBox(width: 5),
                            Text(
                              '更新内容',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: LoveGirlTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 可滚动的更新列表
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: changelogLines.map((line) {
                                final isBullet = line.startsWith(
                                    RegExp(r'^[-•·✨🆕✅🌤🔧💾⬇️🎨🐛📊💕🎉]'));
                                final text = isBullet
                                    ? line.replaceFirst(
                                        RegExp(r'^[-•·]\s*'), '')
                                    : line;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isBullet) ...[
                                        Container(
                                          margin:
                                              const EdgeInsets.only(top: 6),
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: LoveGirlTheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isBullet
                                                ? LoveGirlTheme.textPrimary
                                                : LoveGirlTheme.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ===== 按钮区域（固定在底部）=====
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  children: [
                    // 立即更新按钮
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDownloadDialog(context, downloadUrl);
                          LogService().userAction(
                              '版本更新:下载 $currentVersionLabel → v$latestVersionName');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LoveGirlTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '立即更新',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    // 跳过此版本（非强制更新时显示）
                    if (!forceUpdate) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton(
                          onPressed: () async {
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '跳过此版本',
                            style: TextStyle(fontSize: 13),
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

/// 显示下载进度弹窗
void _showDownloadDialog(BuildContext context, String downloadUrl) {
  if (downloadUrl.isEmpty || downloadUrl == AppConstants.baseUrl) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('下载链接无效，请稍后再试'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  double progress = 0;
  bool downloading = true;
  bool failed = false;
  String errorMsg = '';

  // 用于保存 setDialogState 回调
  StateSetter? _setDialogState;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        // 保存 setDialogState 以便在回调中使用
        _setDialogState = setDialogState;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: LoveGirlTheme.cardLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : downloading
                            ? Icons.download_rounded
                            : Icons.check_circle_outline_rounded,
                    color: failed
                        ? LoveGirlTheme.red
                        : downloading
                            ? LoveGirlTheme.primary
                            : const Color(0xFF4CAF50),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed
                      ? '下载失败'
                      : downloading
                          ? '正在下载...'
                          : '下载完成',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // 进度条
                if (downloading && !failed) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: LoveGirlTheme.separator,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          LoveGirlTheme.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress > 0
                        ? '${(progress * 100).toStringAsFixed(0)}%'
                        : '准备下载...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: LoveGirlTheme.textMuted,
                    ),
                  ),
                ],
                // 错误信息
                if (failed) ...[
                  Text(
                    errorMsg.isNotEmpty ? errorMsg : '请检查网络后重试',
                    style: const TextStyle(
                      fontSize: 13,
                      color: LoveGirlTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDownloadDialog(context, downloadUrl);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LoveGirlTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('重试'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  // 开始下载
  _downloadApk(
    downloadUrl,
    onProgress: (p) {
      if (context.mounted && _setDialogState != null) {
        _setDialogState!(() {
          progress = p;
        });
      }
    },
    onComplete: (filePath) {
      if (context.mounted) {
        if (_setDialogState != null) {
          _setDialogState!(() {
            downloading = false;
            progress = 1.0;
          });
        }
        // 延迟一下再关闭弹窗并安装，让用户看到"下载完成"
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            Navigator.of(context).pop(); // 关闭进度弹窗
            _installApk(filePath);
          }
        });
      }
    },
    onError: (error) {
      if (context.mounted) {
        if (_setDialogState != null) {
          _setDialogState!(() {
            downloading = false;
            failed = true;
            errorMsg = error.toString();
          });
        }
      }
    },
  );
}

/// 下载 APK
Future<void> _downloadApk(
  String url, {
  void Function(double)? onProgress,
  void Function(String)? onComplete,
  void Function(String)? onError,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/LoveGirl-latest.apk';

    final dio = Dio();
    await dio.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    if (onComplete != null) onComplete(filePath);
  } catch (e) {
    LogService().error('Version', 'APK下载失败: $e');
    if (onError != null) onError(e.toString());
  }
}

/// 安装 APK
Future<void> _installApk(String filePath) async {
  try {
    LogService().info('Version', '开始安装APK: $filePath');

    // 使用 open_filex 触发系统安装界面
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );

    LogService().info('Version', 'open_filex结果: ${result.type}');

    // 如果 open_filex 没有成功，尝试其他方式
    if (result.type != ResultType.done) {
      LogService().info('Version', '尝试使用 url_launcher 打开');

      // 尝试使用 url_launcher
      final uri = Uri.parse('file://$filePath');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        LogService().error('Version', '无法打开APK文件');
        // 如果都失败了，提示用户手动安装
        _showManualInstallHint(filePath);
      }
    }
  } catch (e) {
    LogService().error('Version', '安装APK异常: $e');
    _showManualInstallHint(filePath);
  }
}

/// 显示手动安装提示
void _showManualInstallHint(String filePath) {
  // 这里可以显示一个对话框提示用户手动安装
  LogService().info('Version', '请手动安装APK: $filePath');
}

/// 在浏览器中打开
Future<void> _launchInBrowser(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    LogService().error('Version', '打开浏览器失败: $e');
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

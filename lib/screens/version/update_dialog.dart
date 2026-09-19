import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';

const _kIgnoredVersionKey = 'ignored_update_version';

Future<void> showUpdateDialog(
  BuildContext context,
  Map<String, dynamic> data, {
  bool forceUpdate = false,
}) async {
  final version = data['version'] as Map<String, dynamic>? ?? const {};
  final changelog = (version['changelog'] ?? '').toString();
  final latestVersionName = (version['name'] ?? '').toString();
  final url = (version['url'] ?? '').toString();
  final currentVersionLabel =
      'v${AppConstants.versionName} (build ${AppConstants.versionCode})';
  final changelogLines = _normalizeChangelog(changelog);
  final downloadUrl =
      url.startsWith('http') ? url : '${AppConstants.baseUrl}$url';

  return showDialog<void>(
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
            color: context.lgCard,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: LoveGirlTheme.gradientLove,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: context.lgInk.withAlpha(50),
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
                    SizedBox(height: 12),
                    Text(
                      '发现新版本',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: context.lgTextPrimary,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.lgBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentVersionLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.lgTextMuted,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: context.lgInk,
                            ),
                          ),
                          Text(
                            'v$latestVersionName',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.lgInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (changelogLines.isNotEmpty)
                Flexible(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.lgBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                              color: context.lgInk,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '更新内容',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.lgTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: changelogLines.map((line) {
                                final isBullet = line.isBullet;
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
                                          decoration: BoxDecoration(
                                            color: context.lgInk,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          line.text,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isBullet
                                                ? context.lgTextPrimary
                                                : context.lgTextSecondary,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDownloadDialog(context, downloadUrl);
                          LogService().userAction(
                            '版本更新: 下载 $currentVersionLabel -> v$latestVersionName',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.lgInk,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '立即更新',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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
                              _kIgnoredVersionKey,
                              latestVersionName,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            LogService().userAction(
                              '版本更新: 跳过 v$latestVersionName',
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: context.lgTextMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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

void _showDownloadDialog(BuildContext context, String downloadUrl) {
  if (downloadUrl.isEmpty || downloadUrl == AppConstants.baseUrl) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('下载链接无效，请稍后再试'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  var progress = 0.0;
  var downloading = true;
  var failed = false;
  var errorMsg = '';
  StateSetter? setDownloadDialogState;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        setDownloadDialogState = setDialogState;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.lgCard,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.lgInk.withAlpha(20),
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
                            ? context.lgInk
                            : const Color(0xFF4CAF50),
                    size: 28,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  failed
                      ? '下载失败'
                      : downloading
                          ? '正在下载...'
                          : '下载完成',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.lgTextPrimary,
                  ),
                ),
                SizedBox(height: 16),
                if (downloading && !failed) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: context.lgSeparator,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.lgInk,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    progress > 0
                        ? '${(progress * 100).toStringAsFixed(0)}%'
                        : '准备下载...',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.lgTextMuted,
                    ),
                  ),
                ],
                if (failed) ...[
                  Text(
                    errorMsg.isNotEmpty ? errorMsg : '请检查网络后重试',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.lgTextMuted,
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
                        backgroundColor: context.lgInk,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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

  _downloadApk(
    downloadUrl,
    onProgress: (value) {
      if (context.mounted && setDownloadDialogState != null) {
        setDownloadDialogState!(() => progress = value);
      }
    },
    onComplete: (filePath) {
      if (!context.mounted || setDownloadDialogState == null) return;
      setDownloadDialogState!(() {
        downloading = false;
        progress = 1;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        _installApk(filePath);
      });
    },
    onError: (error) {
      if (!context.mounted || setDownloadDialogState == null) return;
      setDownloadDialogState!(() {
        downloading = false;
        failed = true;
        errorMsg = error;
      });
    },
  );
}

Future<void> _downloadApk(
  String url, {
  void Function(double)? onProgress,
  void Function(String)? onComplete,
  void Function(String)? onError,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/LoveGirl-latest.apk';
    final oldFile = File(filePath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheBustUrl =
        url.contains('?') ? '$url&_t=$timestamp' : '$url?_t=$timestamp';

    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.receiveTimeout = const Duration(minutes: 5);

    await dio.download(
      cacheBustUrl,
      filePath,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    final file = File(filePath);
    if (!await file.exists() || await file.length() < 1024 * 1024) {
      throw Exception('下载的 APK 文件无效');
    }

    onComplete?.call(filePath);
  } catch (e) {
    LogService().error('Version', 'APK 下载失败: $e');
    onError?.call(e.toString());
  }
}

Future<void> _installApk(String filePath) async {
  try {
    LogService().info('Version', '开始安装 APK: $filePath');

    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );

    LogService().info('Version', 'open_filex 结果: ${result.type}');
    if (result.type == ResultType.done) return;

    LogService().info('Version', '尝试使用 url_launcher 打开安装包');
    final uri = Uri.parse('file://$filePath');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    LogService().error('Version', '无法打开 APK 文件');
    _showManualInstallHint(filePath);
  } catch (e) {
    LogService().error('Version', '安装 APK 异常: $e');
    _showManualInstallHint(filePath);
  }
}

void _showManualInstallHint(String filePath) {
  LogService().info('Version', '请手动安装 APK: $filePath');
}

Future<void> checkVersionUpdate(BuildContext context) async {
  await _doCheck(context, silent: true);
}

Future<void> manualCheckVersion(BuildContext context) async {
  await _doCheck(context, silent: false);
}

Future<void> _doCheck(BuildContext context, {required bool silent}) async {
  try {
    final res = await ApiService().checkVersion(AppConstants.versionCode);
    final data = res.data?['data'] as Map<String, dynamic>?;
    final hasUpdate = data?['hasUpdate'] == true;

    if (hasUpdate && data != null) {
      final version = data['version'] as Map<String, dynamic>? ?? const {};
      final latestVersionName = (version['name'] ?? '').toString();

      if (silent) {
        final prefs = await SharedPreferences.getInstance();
        final ignoredVersion = prefs.getString(_kIgnoredVersionKey);
        if (ignoredVersion == latestVersionName) {
          LogService().info('Version', '用户已跳过 v$latestVersionName，本次不弹窗');
          return;
        }
      }

      if (context.mounted) {
        await showUpdateDialog(
          context,
          data,
          forceUpdate: data['needUpdate'] == true,
        );
      }
    } else if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('当前已经是最新版本 v${AppConstants.versionName}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    LogService().info(
      'Version',
      '版本检查完成(${silent ? "自动" : "手动"}): 当前=v${AppConstants.versionName} build${AppConstants.versionCode}, 有更新=$hasUpdate',
    );
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

List<_ChangelogLine> _normalizeChangelog(String raw) {
  return raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final isBullet = RegExp(r'^[-*•·]').hasMatch(line);
        final text =
            isBullet ? line.replaceFirst(RegExp(r'^[-*•·]\s*'), '') : line;
        return _ChangelogLine(text: text, isBullet: isBullet);
      })
      .toList();
}

class _ChangelogLine {
  final String text;
  final bool isBullet;

  const _ChangelogLine({
    required this.text,
    required this.isBullet,
  });
}

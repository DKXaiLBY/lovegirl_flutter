import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../services/update_download.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';

const _kIgnoredVersionKey = 'ignored_update_version';

Future<void> showUpdateDialog(
  BuildContext context,
  Map<String, dynamic> data, {
  bool forceUpdate = false,
}) async {
  final version = data['version'] as Map<String, dynamic>? ?? const {};
  final changelog = (version['changelog'] ?? '').toString();
  final latestVersionName = (version['name'] ?? '').toString();
  final package =
      UpdatePackage.fromVersion(version, Uri.parse(AppConstants.baseUrl));
  final currentVersionLabel =
      'v${AppConstants.versionName} (build ${AppConstants.versionCode})';
  final changelogLines = _normalizeChangelog(changelog);
  final saved = await UpdateDownload.instance.progress(package);
  if (!context.mounted) return;

  return showDialog<void>(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (ctx) => PopScope(
      canPop: !forceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: RebuildGlass(
            radius: LoveGirlTheme.radiusXl,
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
                            _showDownloadDialog(
                                context, package, saved, forceUpdate);
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
                          child: Text(
                            saved.complete
                                ? '安装更新'
                                : saved.bytes > 0
                                    ? '继续下载 · ${_percent(saved.bytes, package.size)}%'
                                    : '立即更新',
                            style: const TextStyle(
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
                              if (saved.bytes > 0) {
                                Navigator.pop(ctx);
                                return;
                              }
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
                            child: Text(
                              saved.bytes > 0 ? '稍后继续' : '跳过此版本',
                              style: const TextStyle(fontSize: 13),
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
    ),
  );
}

int _percent(int bytes, int total) => (bytes * 100 ~/ total).clamp(0, 100);

String _megabytes(int bytes) => (bytes / 1000000).toStringAsFixed(1);

void _showDownloadDialog(
  BuildContext context,
  UpdatePackage package,
  UpdateProgress saved,
  bool forceUpdate,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDownloadDialog(
      package: package,
      saved: saved,
      forceUpdate: forceUpdate,
    ),
  );
}

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({
    required this.package,
    required this.saved,
    required this.forceUpdate,
  });

  final UpdatePackage package;
  final UpdateProgress saved;
  final bool forceUpdate;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  late int _bytes = widget.saved.bytes;
  CancelToken? _transfer;
  File? _apk;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _download();
    });
  }

  Future<void> _download() async {
    if (_transfer != null) return;
    final token = CancelToken();
    setState(() {
      _transfer = token;
      _error = null;
    });
    try {
      final file = await UpdateDownload.instance.download(
        widget.package,
        token,
        (bytes) {
          if (mounted && _bytes != bytes) setState(() => _bytes = bytes);
        },
      );
      if (mounted) setState(() => _apk = file);
    } catch (error) {
      final cancelled = token.isCancelled;
      if (!cancelled) {
        LogService().error('Version', 'APK 下载失败: ${error.runtimeType}');
      }
      if (!mounted) return;
      var bytes = _bytes;
      try {
        bytes = (await UpdateDownload.instance.progress(widget.package)).bytes;
      } on FileSystemException {
        // Keep the last known progress if local storage is unavailable.
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        if (!cancelled) {
          _error = switch (error) {
            UpdateDownloadException() => error.message,
            FileSystemException() => '暂时无法保存安装包，请检查可用空间',
            _ => '下载中断，请检查网络后继续',
          };
        }
      });
    } finally {
      if (mounted) setState(() => _transfer = null);
    }
  }

  @override
  void dispose() {
    _transfer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transfer = _transfer;
    final apk = _apk;
    final size = widget.package.size;
    final percent = _percent(_bytes, size);
    final headline = apk != null
        ? '下载完成'
        : transfer?.isCancelled == true
            ? '正在暂停'
            : transfer != null
                ? (_bytes == size ? '正在校验安装包' : '正在下载更新')
                : (_error == null ? '下载已暂停' : '下载中断');

    return PopScope(
      canPop: !widget.forceUpdate,
      child: AlertDialog(
        scrollable: true,
        title: Text(headline),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _bytes / size),
            const SizedBox(height: 12),
            Text(
                '$percent%  ·  ${_megabytes(_bytes)} / ${_megabytes(size)} MB'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!),
            ],
          ],
        ),
        actions: [
          if (!widget.forceUpdate && transfer == null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后继续'),
            ),
          if (apk != null)
            FilledButton(
              onPressed: () => _installApk(apk.path),
              child: const Text('安装更新'),
            )
          else if (transfer != null)
            TextButton(
              onPressed:
                  transfer.isCancelled ? null : () => setState(transfer.cancel),
              child: const Text('暂停下载'),
            )
          else
            FilledButton(
              onPressed: _download,
              child: Text(_bytes > 0 ? '继续下载' : '重新下载'),
            ),
        ],
      ),
    );
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
    final text = isBullet ? line.replaceFirst(RegExp(r'^[-*•·]\s*'), '') : line;
    return _ChangelogLine(text: text, isBullet: isBullet);
  }).toList();
}

class _ChangelogLine {
  final String text;
  final bool isBullet;

  const _ChangelogLine({
    required this.text,
    required this.isBullet,
  });
}

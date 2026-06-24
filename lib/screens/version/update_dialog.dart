import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';

/// 显示版本更新弹窗（二级弹窗，聚焦更新日志）
///
/// [data] 是 API 返回的 data 字段
/// [forceUpdate] 为 true 时弹窗不可关闭（强制更新）
Future<void> showUpdateDialog(BuildContext context, Map<String, dynamic> data, {bool forceUpdate = false}) {
  final version = data['version'] as Map<String, dynamic>? ?? {};
  final changelog = (version['changelog'] ?? '').toString();
  final latestVersionName = (version['name'] ?? '').toString();
  final latestVersionCode = version['code'] ?? 0;
  final size = (version['size'] ?? '未知').toString();
  final url = (version['url'] ?? '').toString();
  final currentVersionLabel = 'v${AppConstants.versionName} (build ${AppConstants.versionCode})';

  // 解析 changelog 为条目列表
  final changelogLines = changelog
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  return showDialog(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (ctx) => PopScope(
      canPop: !forceUpdate,
      child: Center(
        child: Container(
          // 适当大小：宽度最大400，高度最大屏幕的75%
          width: MediaQuery.of(ctx).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: LoveGirlTheme.cardLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== 头部：版本信息 =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
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
                      ),
                      child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '发现新版本',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: LoveGirlTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    // 版本对比行
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.bgLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentVersionLabel,
                            style: const TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.arrow_forward_rounded, size: 18, color: LoveGirlTheme.primary),
                          ),
                          Text(
                            'v$latestVersionName (build $latestVersionCode)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LoveGirlTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===== 分割线 =====
              const Divider(height: 1, indent: 20, endIndent: 20),

              // ===== 更新日志（核心区域，可滚动）=====
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 18, color: LoveGirlTheme.primary),
                          SizedBox(width: 6),
                          Text(
                            '本次更新',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LoveGirlTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: changelogLines.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    '暂无更新说明',
                                    style: TextStyle(fontSize: 14, color: LoveGirlTheme.textMuted),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: changelogLines.length,
                                itemBuilder: (_, i) {
                                  final line = changelogLines[i];
                                  // 识别以 - • · 开头的条目
                                  final isBullet = line.startsWith('-') || line.startsWith('•') || line.startsWith('·');
                                  final text = isBullet ? line.substring(1).trim() : line;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isBullet ? LoveGirlTheme.primary : LoveGirlTheme.textMuted,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isBullet ? LoveGirlTheme.textPrimary : LoveGirlTheme.textSecondary,
                                              height: 1.55,
                                              fontWeight: isBullet ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== 底部信息 + 按钮 =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // 安装包大小
                    if (size != '未知')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_outlined, size: 14, color: LoveGirlTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '安装包 $size',
                              style: const TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    // 按钮行
                    Row(
                      children: [
                        if (!forceUpdate) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LoveGirlTheme.textSecondary,
                                side: BorderSide(color: LoveGirlTheme.separator.withAlpha(200)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('稍后再说', style: TextStyle(fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: forceUpdate ? 1 : 1,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (url.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('下载链接已复制到剪贴板，请在浏览器中打开下载'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                LogService().userAction('版本更新:复制下载链接 $currentVersionLabel → v$latestVersionName');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('请前往应用商店或官网下载最新版本'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LoveGirlTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('立即更新', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
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

/// 检查版本更新（静默模式：有更新弹窗，无更新静默）
/// 用于 App 启动时自动检查
Future<void> checkVersionUpdate(BuildContext context) async {
  await _doCheck(context, silent: true);
}

/// 手动检查版本更新（显示结果：有更新弹窗，无更新提示）
/// 用于设置页手动触发
Future<void> manualCheckVersion(BuildContext context) async {
  await _doCheck(context, silent: false);
}

Future<void> _doCheck(BuildContext context, {required bool silent}) async {
  try {
    final res = await ApiService().checkVersion(AppConstants.versionCode);
    final data = res.data?['data'];
    final hasUpdate = data != null && data['hasUpdate'] == true;

    if (hasUpdate) {
      if (context.mounted) {
        showUpdateDialog(context, data!, forceUpdate: data['needUpdate'] == true);
      }
    } else if (!silent) {
      // 手动模式：告知用户已经是最新版本
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('当前已是最新版本 v${AppConstants.versionName} (build ${AppConstants.versionCode})'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    LogService().info('Version', '版本检查完成(${silent ? "自动" : "手动"}): 当前=v${AppConstants.versionName} build${AppConstants.versionCode}, 有更新=$hasUpdate');
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

import 'package:flutter/material.dart';
import '../utils/lovegirl_theme.dart';

/// 通用空状态组件 — 无数据 / 无网络 / 错误
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final String retryText;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
    String? retryText,
  }) : retryText = retryText ?? '重试';

  /// 暂无数据
  const EmptyState.noData({
    super.key,
    this.title = '暂无数据',
    this.subtitle,
  })  : icon = Icons.inbox_outlined,
        onRetry = null,
        retryText = '重试';

  /// 无网络
  const EmptyState.noNetwork({
    super.key,
    this.onRetry,
  })  : icon = Icons.wifi_off_rounded,
        title = '网络连接失败',
        subtitle = '请检查网络设置后重试',
        retryText = '重试';

  /// 加载错误
  const EmptyState.error({
    super.key,
    this.onRetry,
  })  : icon = Icons.error_outline_rounded,
        title = '加载失败',
        subtitle = '请稍后再试',
        retryText = '重试';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: LoveGirlTheme.textMuted),
            const SizedBox(height: LoveGirlTheme.spaceMd),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: LoveGirlTheme.spaceXs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: LoveGirlTheme.textMuted,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: LoveGirlTheme.spaceLg),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LoveGirlTheme.primary,
                  side: const BorderSide(color: LoveGirlTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(retryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

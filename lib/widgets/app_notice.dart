import 'package:flutter/material.dart';

/// 页面顶部横幅（未登录 / 冷却 / 错误）。
///
/// [error] 为 true 用 errorContainer，否则用 tertiaryContainer；传了 [icon]
/// 会渲染成「图标 + 文本」，否则退化成纯文本块（保持各页原有外观）。
class AppNotice extends StatelessWidget {
  final String text;
  final bool error;
  final IconData? icon;

  const AppNotice(
    this.text, {
    super.key,
    this.error = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = error
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5);
    final fg = error
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: icon == null
          ? Text(text, style: theme.textTheme.bodySmall?.copyWith(color: fg))
          : Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 统一的 SnackBar 入口，替代各页重复的 `ScaffoldMessenger...showSnackBar`。
extension AppSnack on BuildContext {
  void showSnack(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

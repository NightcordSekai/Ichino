import 'package:flutter/material.dart';

import '../config/strings.dart';

/// 全站统一的卡片外壳：无阴影、16 圆角、outline 描边。
///
/// 之前每个页面各写一份 `Card(elevation: 0, shape: RoundedRectangleBorder(...))`，
/// 改一处圆角/描边要改十几个文件。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor ??
              theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 卡片内的标题行：图标 + 彩色标题。
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final double iconSize;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: iconSize, color: tint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// 「完成后自动退出登录并返回标题页」勾选框。
///
/// 六个功能页原本各抄一份 `InkWell + Checkbox + Text`，现在统一成一个卡片。
class AutoLogoutToggle extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final String label;

  const AutoLogoutToggle({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.label = AppStrings.autoLogoutAndExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? () => onChanged?.call(!value) : null,
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged:
                  enabled ? (v) => onChanged?.call(v ?? false) : null,
            ),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? null
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_card.dart';

/// 高危操作共用的执行阶段。
///
/// 六个功能页原来各自定义 `_Step` / `TicketStep` / `MusicRiskStep`，值完全一样
/// （功能票用 `chargeTicket` 表示「发包」，语义上就是 [upload]）。
enum RiskStep { idle, fetchData, upload, logout, complete, failed }

/// 执行进度卡：按顺序展示各阶段，前/当前/后三种状态。
///
/// 说明文字 [message] 用错误色高亮；[error] 用于额外展示底层异常文本。
class StepProgressCard extends StatelessWidget {
  final RiskStep step;
  final String message;
  final String? error;

  /// 要展示的 (阶段, 文案) 列表，按执行顺序给出。不含 [RiskStep.idle] / [RiskStep.failed]。
  final List<(RiskStep, String)> steps;

  const StepProgressCard({
    super.key,
    required this.step,
    required this.steps,
    this.message = '',
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = step == RiskStep.failed;
    final isDone = step == RiskStep.complete;

    return AppCard(
      borderColor: isFailed
          ? theme.colorScheme.error.withValues(alpha: 0.5)
          : isDone
              ? Colors.green.withValues(alpha: 0.5)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (stage, label) in steps) _row(theme, stage, label),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            _banner(
              theme,
              message,
              background: isFailed
                  ? theme.colorScheme.errorContainer
                  : isDone
                      ? Colors.green.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceContainerHighest,
              foreground: isFailed
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSurface,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            _banner(
              theme,
              error!,
              background: theme.colorScheme.errorContainer,
              foreground: theme.colorScheme.onErrorContainer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _banner(
    ThemeData theme,
    String text, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: foreground,
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, RiskStep stage, String label) {
    // failed 卡在发包阶段，按原逻辑回退到 upload。
    final current = step == RiskStep.failed ? RiskStep.upload : step;
    const order = [
      RiskStep.fetchData,
      RiskStep.upload,
      RiskStep.logout,
      RiskStep.complete,
    ];
    final done = order.indexOf(current) > order.indexOf(stage);
    final active = step == stage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : active
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
            size: 18,
            color: done
                ? Colors.green
                : active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

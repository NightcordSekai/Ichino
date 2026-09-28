import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../config/strings.dart';
import '../models/session_model.dart';
import '../models/session_share.dart';
import 'app_card.dart';
import 'app_notice.dart';

/// 实验性：把当前会话打包成 Base64「连接信息」，在别的设备粘贴即可恢复。
class ConnectionShareCard extends StatefulWidget {
  final int userId;
  final String token;

  const ConnectionShareCard({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<ConnectionShareCard> createState() => _ConnectionShareCardState();
}

class _ConnectionShareCardState extends State<ConnectionShareCard> {
  String? _encoded;

  SessionShare get _share => SessionModel.instance.exportConnectionInfo(
    userId: widget.userId,
    token: widget.token,
  );

  Future<void> _copy() async {
    final share = _share;
    if (!share.hasCookie && !share.hasToken) {
      context.showSnack(AppStrings.connectionShareEmpty);
      return;
    }

    final text = share.encode();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _encoded = text);
    context.showSnack(AppStrings.connectionShareCopied);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionTitle(
                  icon: Icons.link,
                  title: AppStrings.connectionShareTitle,
                ),
              ),
              const _ExperimentalBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.connectionShareDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_all, size: 20),
              label: const Text(AppStrings.connectionShareCopy),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_encoded != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _encoded!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.connectionShareSecurity,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExperimentalBadge extends StatelessWidget {
  const _ExperimentalBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: 0.5)),
      ),
      child: Text(
        AppStrings.experimentalBadge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

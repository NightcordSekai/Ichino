import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: responsiveBody(
        context,
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.qr_code_scanner,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.aboutTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.aboutDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    icon: Icons.info_outline,
                    title: AppStrings.aboutBasics,
                  ),
                  const SizedBox(height: 14),
                  _row(theme, AppStrings.creditBuiltWith, 'Flutter'),
                  _row(
                    theme,
                    AppStrings.aboutPlatforms,
                    'Android · iOS · Windows · macOS · Linux',
                  ),
                  _row(theme, AppStrings.aboutPackageId, 'dev.naominet.ichino'),
                  _row(theme, AppStrings.creditLicense, 'MIT'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    icon: Icons.group_outlined,
                    title: AppStrings.credits,
                  ),
                  const SizedBox(height: 14),
                  _row(theme, AppStrings.creditProtocol, 'empurple · eaquira'),
                  _row(theme, AppStrings.creditB50, 'Empurple'),
                  _row(theme, AppStrings.creditQRDecode, '原生 MethodChannel'),
                  _row(theme, AppStrings.creditIconAssets, 'assets2.lxns.net'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const AppNotice(
              AppStrings.aboutRiskNotice,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

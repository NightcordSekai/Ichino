import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../widgets/app_notice.dart';
import '../widgets/cooldown_mixin.dart';
import 'collectibles_page.dart';
import 'kaleidx_scope_page.dart';
import 'map_traverse_page.dart';
import 'number_patch_page.dart';
import 'travel_partner_page.dart';
import 'unlock_music_page.dart';

/// 高危功能中转页：导航到解锁歌曲 / 收藏品获取 / 旅行伙伴 / 数值修改。
/// 各 feature 互相独立，执行流程互不影响。
class HighRiskFeaturePage extends StatefulWidget {
  final int userId;
  final String? cookies;

  /// `loginDateTime` 来自 HomePage 启动时执行的 UserLoginApi。
  /// 为 `null` 时表示当前未持有有效登录态。
  final int? loginDateTime;

  /// UserLoginApi 返回的 loginId / lastLoginDate, 组装 UserAll 需要。
  final int? loginId;
  final String? lastLoginDate;

  /// 完成后自动退出登录并返回标题页，由 HomePage 执行结算+退登+pop。
  final Future<void> Function()? onExitToTitle;

  const HighRiskFeaturePage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.lastLoginDate,
    this.onExitToTitle,
  });

  @override
  State<HighRiskFeaturePage> createState() => _HighRiskFeaturePageState();
}

class _HighRiskFeaturePageState extends State<HighRiskFeaturePage>
    with CooldownMixin<HighRiskFeaturePage> {
  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  void _openUnlockMusic() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnlockMusicPage(
          userId: widget.userId,
          cookies: widget.cookies,
          loginDateTime: widget.loginDateTime,
          loginId: widget.loginId,
          lastLoginDate: widget.lastLoginDate,
          onExitToTitle: widget.onExitToTitle,
        ),
      ),
    );
  }

  void _openCollectibles() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectiblesPage(
          userId: widget.userId,
          cookies: widget.cookies,
          loginDateTime: widget.loginDateTime,
          loginId: widget.loginId,
          lastLoginDate: widget.lastLoginDate,
          onExitToTitle: widget.onExitToTitle,
        ),
      ),
    );
  }

  void _openTravelPartner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TravelPartnerPage(
          userId: widget.userId,
          cookies: widget.cookies,
          loginDateTime: widget.loginDateTime,
          loginId: widget.loginId,
          onExitToTitle: widget.onExitToTitle,
        ),
      ),
    );
  }

  void _openNumberPatch(NumberPatchMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NumberPatchPage(
          userId: widget.userId,
          cookies: widget.cookies,
          loginDateTime: widget.loginDateTime,
          loginId: widget.loginId,
          onExitToTitle: widget.onExitToTitle,
          mode: mode,
        ),
      ),
    );
  }

  void _openMapTraverse() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapTraversePage(
          userId: widget.userId,
          cookies: widget.cookies,
          loginDateTime: widget.loginDateTime,
          loginId: widget.loginId,
          onExitToTitle: widget.onExitToTitle,
        ),
      ),
    );
  }

  void _openKaleidxScope() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KaleidxScopePage(
          userId: widget.userId,
          cookies: widget.cookies,
          loginDateTime: widget.loginDateTime,
          loginId: widget.loginId,
          onExitToTitle: widget.onExitToTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!TitleServerConfigHolder().isConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_ethernet,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(AppStrings.ticketNotConfigured,
                  style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: responsiveBody(
        context,
        child: Column(
          children: [
            if (!isLoggedIn)
              AppNotice(
                AppStrings.musicRiskHubNotLoggedIn,
                error: true,
                icon: Icons.warning_amber_rounded,
              ),
            if (isLoggedIn && cooldownRemaining > 0)
              AppNotice(
                AppStrings.musicRiskHubCooldownNotice(cooldownRemaining),
                icon: Icons.timer_outlined,
              ),
            _buildDescCard(theme),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.lock_open,
              title: AppStrings.unlockFeatureTitle,
              desc: AppStrings.unlockFeatureDesc,
              onTap: _openUnlockMusic,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.card_giftcard,
              title: AppStrings.collectiblesFeatureTitle,
              desc: AppStrings.collectiblesFeatureDesc,
              onTap: _openCollectibles,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.workspace_premium_outlined,
              title: AppStrings.travelPartnerFeatureTitle,
              desc: AppStrings.travelPartnerFeatureDesc,
              onTap: _openTravelPartner,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.speed,
              title: AppStrings.ratingFeatureTitle,
              desc: AppStrings.ratingFeatureDesc,
              onTap: () => _openNumberPatch(NumberPatchMode.rating),
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.commute,
              title: AppStrings.maiMileFeatureTitle,
              desc: AppStrings.maiMileFeatureDesc,
              onTap: () => _openNumberPatch(NumberPatchMode.maiMile),
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.map_outlined,
              title: AppStrings.mapFeatureTitle,
              desc: AppStrings.mapFeatureDesc,
              onTap: _openMapTraverse,
            ),
            const SizedBox(height: 12),
            _buildNavCard(
              theme,
              icon: Icons.science_outlined,
              title: AppStrings.kaleidxFeatureTitle,
              desc: AppStrings.kaleidxFeatureDesc,
              onTap: _openKaleidxScope,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.musicRiskHubTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.musicRiskHubDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

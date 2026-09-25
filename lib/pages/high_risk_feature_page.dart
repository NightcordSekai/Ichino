import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import 'collectibles_page.dart';
import 'travel_partner_page.dart';
import 'unlock_music_page.dart';

/// 高危功能中转页：导航到 UnlockMusic (解锁歌曲) / 收藏品获取。
/// 两个 feature 互相独立，各自的执行流程互不影响。
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

class _HighRiskFeaturePageState extends State<HighRiskFeaturePage> {
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void didUpdateWidget(covariant HighRiskFeaturePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _syncCooldown() {
    _cooldownTimer?.cancel();
    final loginDateTime = widget.loginDateTime;
    if (loginDateTime == null) {
      _cooldownRemaining = 0;
      return;
    }
    _cooldownRemaining = _computeRemaining(loginDateTime);
    if (_cooldownRemaining <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _computeRemaining(loginDateTime);
      setState(() => _cooldownRemaining = remaining);
      if (remaining <= 0) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
    });
  }

  int _computeRemaining(int loginDateTime) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = nowSec - loginDateTime;
    final remaining = AppStrings.ticketCooldownSeconds - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

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
            if (widget.loginDateTime == null) _buildNotLoggedInBanner(theme),
            if (widget.loginDateTime != null && _cooldownRemaining > 0)
              _buildCooldownBanner(theme),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedInBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.musicRiskHubNotLoggedIn,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCooldownBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              size: 18, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.musicRiskHubCooldownNotice(_cooldownRemaining),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
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

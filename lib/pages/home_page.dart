import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/session_model.dart';
import '../models/user_data.dart';
import '../models/user_preview.dart';
import '../services/title_api_service.dart';
import 'about_page.dart';
import 'best50_page.dart';
import 'high_risk_feature_page.dart';
import 'settings_page.dart';
import 'ticket_page.dart';


class HomePage extends StatefulWidget {
  final int userId;
  final String token;
  final bool forcePreviewApi;

  const HomePage({
    super.key,
    required this.userId,
    required this.token,
    this.forcePreviewApi = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;
  UserPreviewDataBean? _preview;
  UserDataBean? _userData;
  String? _error;
  bool _loading = true;
  bool _loggingOut = false;

  SessionModel get _session => SessionModel.instance;

  static const _tabTitles = [
    AppStrings.tabHome,
    AppStrings.tabTickets,
    AppStrings.tabBest50,
    AppStrings.tabRisk,
    AppStrings.tabSettings,
    AppStrings.tabAbout,
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!TitleServerConfigHolder().isConfigured) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
      _userData = null;
    });
    _session.setGameLogin(null);

    final service = TitleApiService(
      TitleServerConfigHolder().config!,
      cookies: _session.cookies,
    );

    try {
      final preview = await service.getUserPreview(
        userId: widget.userId,
        token: widget.token,
      );
      if (!mounted) return;
      _session.updateCookies(service.cookies);
      setState(() => _preview = preview);

      // isLogin == true => 已有人登录, 不再走完整登录, 直接展示 preview 概要
      // forcePreviewApi => 跳过 UserLoginApi, 仅展示 preview + Login 按钮
      if (preview.isLogin || widget.forcePreviewApi) {
        setState(() => _loading = false);
        return;
      }

      await _session.loginGame(
        userId: widget.userId,
        token: widget.token,
      );
      if (!mounted) return;

      final userDataService = TitleApiService(
        TitleServerConfigHolder().config!,
        cookies: _session.cookies,
      );
      final userData = await userDataService.getUserDataTyped(widget.userId);
      if (!mounted) return;
      _session.updateCookies(userDataService.cookies);
      setState(() {
        _userData = userData;
        _loading = false;
      });
    } on TitleApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _performLogin() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _session.loginGame(
        userId: widget.userId,
        token: widget.token,
      );
      if (!mounted) return;

      final service = TitleApiService(
        TitleServerConfigHolder().config!,
        cookies: _session.cookies,
      );
      final userData = await service.getUserDataTyped(widget.userId);
      if (!mounted) return;
      _session.updateCookies(service.cookies);
      setState(() {
        _userData = userData;
        _loading = false;
      });
    } on TitleApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logoutSession() async {
    await _session.logoutGame(userId: widget.userId);
  }

  Future<void> _performLogoutAndExit() async {
    setState(() => _loggingOut = true);
    if (_session.gameLogin != null) {
      await Future.delayed(const Duration(seconds: 5));
      await _logoutSession();
    }
    _session.reset();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        return PopScope(
          canPop: !_loggingOut,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_loggingOut) {
              _performLogoutAndExit();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: _loggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_back),
                onPressed: _loggingOut ? null : _performLogoutAndExit,
              ),
              title: Text(_tabTitles[_currentTab]),
            ),
            body: IndexedStack(
              index: _currentTab,
              children: [
                _buildBody(theme),
                TicketPage(
                  userId: widget.userId,
                  cookies: _session.cookies,
                  loginDateTime: _session.gameLogin?.loginDateTime,
                  playerRating: _userData?.playerRating ?? _preview?.playerRating ?? 0,
                  onLogoutRequested: _session.gameLogin != null ? _logoutSession : null,
                ),
                Best50Page(
                  userId: widget.userId,
                  cookies: _session.cookies,
                  userName: _userData?.userName ?? _preview?.userName ?? '',
                  iconId: _userData?.iconId ?? _preview?.iconId ?? 0,
                  playerRating: _userData?.playerRating ?? _preview?.playerRating ?? 0,
                ),
                HighRiskFeaturePage(
                  userId: widget.userId,
                  cookies: _session.cookies,
                  loginDateTime: _session.gameLogin?.loginDateTime,
                  loginId: _session.gameLogin?.loginId,
                  lastLoginDate: _session.gameLogin?.lastLoginDate,
                  onLogoutRequested:
                      _session.gameLogin != null ? _logoutSession : null,
                ),
                SettingsPage(showAppBar: false),
                const AboutPage(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentTab,
              onDestinationSelected: (i) => setState(() => _currentTab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: AppStrings.tabHome),
                NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: AppStrings.tabTickets),
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: AppStrings.tabBest50),
                NavigationDestination(icon: Icon(Icons.warning_outlined), selectedIcon: Icon(Icons.inventory_2), label: AppStrings.tabRisk),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: AppStrings.tabSettings),
                NavigationDestination(icon: Icon(Icons.info_outlined), selectedIcon: Icon(Icons.info), label: AppStrings.tabAbout),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!TitleServerConfigHolder().isConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_ethernet, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                AppStrings.titleServerNotConfigured,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.titleServerNotConfiguredDesc,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => setState(() => _currentTab = 4),
                icon: const Icon(Icons.settings, size: 20),
                label: const Text(AppStrings.openSettings),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(AppStrings.loadFailed, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    final preview = _preview;
    final userData = _userData;
    if (preview == null) {
      return const SizedBox.shrink();
    }

    if ((preview.isLogin || (widget.forcePreviewApi && _session.gameLogin == null)) && userData == null) {
      return _buildPreviewOnly(
        theme,
        preview,
        showLoginButton: widget.forcePreviewApi && _session.gameLogin == null,
        onLoginPressed: _performLogin,
      );
    }

    if (userData != null) {
      return _buildFullData(theme, preview, userData);
    }

    return const SizedBox.shrink();
  }

  Widget _buildPreviewOnly(
    ThemeData theme,
    UserPreviewDataBean preview, {
    bool showLoginButton = false,
    VoidCallback? onLoginPressed,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsiveMaxWidth(context)),
        child: Column(
          children: [
            if (preview.errorId != 0) _ErrorIdBanner(theme: theme, errorId: preview.errorId),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                showLoginButton ? 'Preview API 模式，点击下方按钮登录。' : AppStrings.inheritedAccountNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            if (showLoginButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : onLoginPressed,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login, size: 20),
                  label: Text(_loading ? AppStrings.loggingIn : AppStrings.login),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ProfileFromPreviewCard(theme: theme, preview: preview),
            const SizedBox(height: 12),
            ...responsiveGrid(
              context: context,
              children: [
                _PreviewGameInfoCard(theme: theme, preview: preview),
                _PreviewStatusCard(theme: theme, preview: preview),
              ],
            ),
            if (TitleApiService.lastRawResponse != null) ...[
              const SizedBox(height: 12),
              _DebugRawJsonCard(
                theme: theme,
                rawJson: TitleApiService.lastRawResponse!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullData(
    ThemeData theme,
    UserPreviewDataBean preview,
    UserDataBean data,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsiveMaxWidth(context)),
        child: Column(
          children: [
            _ProfileFromUserDataCard(theme: theme, data: data),
            const SizedBox(height: 12),
            ...responsiveGrid(
              context: context,
              children: [
                _RatingBreakdownCard(theme: theme, data: data),
                _FirstPlayCard(theme: theme, data: data),
                _GameInfoFromUserDataCard(theme: theme, data: data),
                _PlayStatsCard(theme: theme, data: data),
                _StatusFromUserDataCard(theme: theme, preview: preview, data: data),
                _UserDataDetailCard(theme: theme, data: data),
              ],
            ),
            if (TitleApiService.lastRawResponse != null) ...[
              const SizedBox(height: 12),
              _DebugRawJsonCard(
                theme: theme,
                rawJson: TitleApiService.lastRawResponse!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Preview-only (isLogin == true) widgets
// =============================================================================

class _ProfileFromPreviewCard extends StatelessWidget {
  final ThemeData theme;
  final UserPreviewDataBean preview;

  const _ProfileFromPreviewCard({required this.theme, required this.preview});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _Avatar(theme: theme, iconId: preview.iconId),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.userName.isEmpty ? AppStrings.unknownUser : preview.userName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.rating(preview.playerRating),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewGameInfoCard extends StatelessWidget {
  final ThemeData theme;
  final UserPreviewDataBean preview;

  const _PreviewGameInfoCard({required this.theme, required this.preview});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      theme: theme,
      title: AppStrings.gameInfo,
      rows: [
        (AppStrings.lastGame, preview.lastGameId),
        (AppStrings.lastPlay, preview.lastPlayDate),
        (AppStrings.lastLogin, preview.lastLoginDate),
        (AppStrings.romVersion, preview.lastRomVersion),
        (AppStrings.dataVersion, preview.lastDataVersion),
      ],
    );
  }
}

class _PreviewStatusCard extends StatelessWidget {
  final ThemeData theme;
  final UserPreviewDataBean preview;

  const _PreviewStatusCard({required this.theme, required this.preview});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.status,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _statusChip(theme, AppStrings.netMember, preview.isNetMember),
            _statusChip(theme, AppStrings.inherit, preview.isInherit),
            _statusChip(
              theme,
              AppStrings.banState,
              preview.banState == 0,
              trueText: AppStrings.clean,
              falseText: '已封禁 (${preview.banState})',
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Full UserData widgets
// =============================================================================

class _ProfileFromUserDataCard extends StatelessWidget {
  final ThemeData theme;
  final UserDataBean data;

  const _ProfileFromUserDataCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _Avatar(theme: theme, iconId: data.iconId),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.userName.isEmpty ? AppStrings.unknownUser : data.userName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.rating(data.playerRating),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.highestRating}: ${data.highestRating}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBreakdownCard extends StatelessWidget {
  final ThemeData theme;
  final UserDataBean data;

  const _RatingBreakdownCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      theme: theme,
      title: AppStrings.ratingBreakdown,
      rows: [
        (AppStrings.musicRating, '${data.musicRating}'),
        (AppStrings.newChartRating, '${data.playerNewRating}'),
        (AppStrings.oldChartRating, '${data.playerOldRating}'),
        (AppStrings.highestRating, '${data.highestRating}'),
      ],
    );
  }
}

class _FirstPlayCard extends StatelessWidget {
  final ThemeData theme;
  final UserDataBean data;

  const _FirstPlayCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      theme: theme,
      title: AppStrings.firstPlay,
      rows: [
        (AppStrings.joinDate, data.firstPlayDate),
        (AppStrings.firstGame, data.firstGameId),
        (AppStrings.firstRomVersion, data.firstRomVersion),
        (AppStrings.firstDataVersion, data.firstDataVersion),
      ],
    );
  }
}

class _GameInfoFromUserDataCard extends StatelessWidget {
  final ThemeData theme;
  final UserDataBean data;

  const _GameInfoFromUserDataCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      theme: theme,
      title: AppStrings.gameInfo,
      rows: [
        (AppStrings.lastGame, data.lastGameId),
        (AppStrings.lastPlay, data.lastPlayDate),
        (AppStrings.lastLogin, data.lastLoginDate),
        (AppStrings.romVersion, data.lastRomVersion),
        (AppStrings.dataVersion, data.lastDataVersion),
        (AppStrings.lastRegion, '${data.lastRegionName}${data.lastRegionId > 0 ? ' (${data.lastRegionId})' : ''}'),
      ],
    );
  }
}

class _PlayStatsCard extends StatelessWidget {
  final ThemeData theme;
  final UserDataBean data;

  const _PlayStatsCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      theme: theme,
      title: AppStrings.playStats,
      rows: [
        (AppStrings.playCount, '${data.playCount}'),
        (AppStrings.currentPlayCount, '${data.currentPlayCount}'),
        (AppStrings.totalAchievement, '${data.totalAchievement}'),
        (AppStrings.totalDxScore, '${data.totalDeluxscore}'),
        (AppStrings.totalSync, '${data.totalSync}'),
        (AppStrings.totalAwake, '${data.totalAwake}'),
      ],
    );
  }
}

class _StatusFromUserDataCard extends StatelessWidget {
  final ThemeData theme;
  final UserPreviewDataBean preview;
  final UserDataBean data;

  const _StatusFromUserDataCard({
    required this.theme,
    required this.preview,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.status,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _statusChip(theme, AppStrings.netMember, data.isNetMember),
            _statusChip(theme, AppStrings.inherit, preview.isInherit),
            _statusChip(
              theme,
              AppStrings.banState,
              data.banState == 0,
              trueText: AppStrings.clean,
              falseText: '已封禁 (${data.banState})',
            ),
            _statusChip(
              theme,
              AppStrings.dailyBonus,
              data.dailyBonusDate.isNotEmpty &&
                  !data.dailyBonusDate.startsWith('1970'),
              trueText: data.dailyBonusDate,
              falseText: AppStrings.notClaimed,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserDataDetailCard extends StatefulWidget {
  final ThemeData theme;
  final UserDataBean data;

  const _UserDataDetailCard({required this.theme, required this.data});

  @override
  State<_UserDataDetailCard> createState() => _UserDataDetailCardState();
}

class _UserDataDetailCardState extends State<_UserDataDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final data = widget.data;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.moreDetails,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 14),
                _detailRow(theme, AppStrings.userId, '${data.userId}'),
                _detailRow(theme, AppStrings.point, '${data.point}'),
                _detailRow(theme, AppStrings.totalPoint, '${data.totalPoint}'),
                _detailRow(theme, AppStrings.iconId, '${data.iconId}'),
                _detailRow(theme, AppStrings.nameplateId, '${data.nameplateId}'),
                _detailRow(theme, AppStrings.plateId, '${data.plateId}'),
                _detailRow(theme, AppStrings.frameId, '${data.frameId}'),
                _detailRow(theme, AppStrings.titleId, '${data.titleId}'),
                _detailRow(theme, AppStrings.trophyId, '${data.trophyId}'),
                _detailRow(theme, AppStrings.partnerId, '${data.partnerId}'),
                _detailRow(theme, AppStrings.gradeRank, '${data.gradeRank}'),
                _detailRow(theme, AppStrings.courseRank, '${data.courseRank}'),
                _detailRow(theme, AppStrings.classRank, '${data.classRank}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

class _SectionCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final List<(String, String)> rows;

  const _SectionCard({
    required this.theme,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            for (final (label, value) in rows) _infoRow(theme, label, value),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final ThemeData theme;
  final int iconId;

  const _Avatar({required this.theme, required this.iconId});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: iconId > 0
          ? NetworkImage('https://assets2.lxns.net/maimai/icon/$iconId.png')
          : null,
      child: iconId == 0
          ? Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer)
          : null,
    );
  }
}

Widget _statusChip(
  ThemeData theme,
  String label,
  dynamic value, {
  String trueText = 'Yes',
  String falseText = 'No',
}) {
  String text;
  Color color;
  if (value is bool) {
    text = value ? trueText : falseText;
    color = value ? Colors.green : Colors.grey;
  } else {
    text = '$value';
    color = theme.colorScheme.onSurface;
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _DebugRawJsonCard extends StatefulWidget {
  final ThemeData theme;
  final String rawJson;

  const _DebugRawJsonCard({
    required this.theme,
    required this.rawJson,
  });

  @override
  State<_DebugRawJsonCard> createState() => _DebugRawJsonCardState();
}

class _DebugRawJsonCardState extends State<_DebugRawJsonCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.rawApiResponse,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.orange,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    widget.rawJson,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorIdBanner extends StatelessWidget {
  final ThemeData theme;
  final int errorId;

  const _ErrorIdBanner({required this.theme, required this.errorId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'API returned errorId: $errorId',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

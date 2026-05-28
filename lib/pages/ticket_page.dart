import 'dart:async';

import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../services/title_api_service.dart';

enum TicketStep {
  idle,
  chargeTicket,
  logout,
  complete,
  failed,
}

class TicketPage extends StatefulWidget {
  final int userId;
  final String? cookies;

  /// `loginDateTime` 来自 HomePage 启动时执行的 UserLoginApi。
  /// 为 `null` 时表示当前未持有有效登录态（例如 isInherit 账号或登录失败）。
  final int? loginDateTime;
  final int playerRating;

  /// 当用户勾选"完成后自动退出登录"时，由 HomePage 负责发送 logout 包。
  final Future<void> Function()? onLogoutRequested;

  const TicketPage({
    super.key,
    required this.userId,
    required this.playerRating,
    this.cookies,
    this.loginDateTime,
    this.onLogoutRequested,
  });

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  static const _ticketNameMap = {
    1: '功能票',
    2: '2倍功能票',
    3: '3倍功能票',
    4: '4倍功能票',
    5: '5倍功能票',
    6: '6倍功能票',
  };

  TicketStep _step = TicketStep.idle;
  String _stepMessage = '';
  String? _error;
  bool _running = false;
  bool _autoLogout = false;

  List<Map<String, dynamic>>? _tickets;
  bool _ticketsLoading = false;
  String? _ticketsError;
  int? _selectedTicketId;

  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  String _ticketName(int chargeId) =>
      _ticketNameMap[chargeId] ?? '票$chargeId';

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void didUpdateWidget(covariant TicketPage oldWidget) {
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

  Map<String, dynamic>? _findTicket(int chargeId) {
    final tickets = _tickets;
    if (tickets == null) return null;
    for (final t in tickets) {
      if ((t['chargeId'] as num?)?.toInt() == chargeId) return t;
    }
    return null;
  }

  void _updateStep(TicketStep step, [String? message]) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _stepMessage = message ?? '';
    });
  }

  Future<void> _loadTickets() async {
    if (!TitleServerConfigHolder().isConfigured) return;

    setState(() {
      _ticketsLoading = true;
      _ticketsError = null;
      _tickets = null;
      _selectedTicketId = null;
    });

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final data = await service.getUserCharge(widget.userId);
      if (!mounted) return;

      final rawList = data['userChargeList'] as List<dynamic>? ?? [];
      setState(() {
        _tickets = rawList.map((e) => e as Map<String, dynamic>).toList();
        _ticketsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ticketsError = e.toString();
        _ticketsLoading = false;
      });
    }
  }

  Future<void> _runTicket() async {
    if (_selectedTicketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ticketNotSelected)),
      );
      return;
    }
    if (!TitleServerConfigHolder().isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ticketNotConfigured)),
      );
      return;
    }
    final loginDateTime = widget.loginDateTime;
    if (loginDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ticketNotLoggedIn)),
      );
      return;
    }
    if (_cooldownRemaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.ticketCooldownNotice(_cooldownRemaining)),
        ),
      );
      return;
    }

    final config = TitleServerConfigHolder().config!;
    final service = TitleApiService(config, cookies: widget.cookies);
    final ticketId = _selectedTicketId!;

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      _updateStep(TicketStep.chargeTicket);
      await service.upsertUserChargeLog(
        userId: widget.userId,
        ticketId: ticketId,
        loginDateTime: loginDateTime,
        playerRating: widget.playerRating,
      );

      if (_autoLogout && widget.onLogoutRequested != null) {
        _updateStep(TicketStep.logout);
        await Future.delayed(const Duration(seconds: 5));
        await widget.onLogoutRequested!();
      }

      _updateStep(
        TicketStep.complete,
        '${AppStrings.ticketUsed}: ${_ticketName(ticketId)}',
      );
    } on TitleApiException catch (e) {
      _updateStep(TicketStep.failed, e.message);
      setState(() => _error = e.message);
    } catch (e) {
      _updateStep(TicketStep.failed, e.toString());
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
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
              Icon(Icons.settings_ethernet, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(AppStrings.ticketNotConfigured, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            if (widget.loginDateTime == null) _buildNotLoggedInBanner(theme),
            if (widget.loginDateTime != null && _cooldownRemaining > 0)
              _buildCooldownBanner(theme),
            _buildTicketListCard(theme),
            const SizedBox(height: 16),
            _buildAutoLogoutToggle(theme),
            const SizedBox(height: 12),
            _buildRunButton(theme),
            if (_step != TicketStep.idle) ...[
              const SizedBox(height: 16),
              _buildProgressCard(theme),
            ],
          ],
        ),
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
              AppStrings.ticketCooldownNotice(_cooldownRemaining),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
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
              AppStrings.ticketNotLoggedIn,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoLogoutToggle(ThemeData theme) {
    final enabled = widget.onLogoutRequested != null && !_running;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled
          ? () => setState(() => _autoLogout = !_autoLogout)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: _autoLogout,
              onChanged: enabled
                  ? (v) => setState(() => _autoLogout = v ?? false)
                  : null,
            ),
            Expanded(
              child: Text(
                AppStrings.ticketAutoLogout,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? null
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketListCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _selectedTicketId != null
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.myTickets,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: _ticketsLoading ? null : _loadTickets,
                    icon: _ticketsLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      _ticketsLoading ? AppStrings.loading : AppStrings.refreshTickets,
                      style: theme.textTheme.labelSmall,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_ticketsError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ticketsError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ..._ticketNameMap.keys.map(
              (id) => _ticketRow(theme, id, _findTicket(id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketRow(ThemeData theme, int chargeId, Map<String, dynamic>? ticket) {
    final hasData = ticket != null;
    final stock = (ticket?['stock'] as num?)?.toInt() ?? 0;
    final validDate = ticket?['validDate'] as String? ?? '-';
    final name = _ticketName(chargeId);
    final isSelected = _selectedTicketId == chargeId;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _running
          ? null
          : () {
              setState(() {
                _selectedTicketId = isSelected ? null : chargeId;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '$chargeId',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  if (hasData)
                    Text(
                      '有效期: $validDate',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary)
            else if (hasData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stock > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '剩余 $stock',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: stock > 0 ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunButton(ThemeData theme) {
    final selectedName = _selectedTicketId != null
        ? _ticketName(_selectedTicketId!)
        : null;
    final onCooldown = _cooldownRemaining > 0;
    final canRun = widget.loginDateTime != null && !_running && !onCooldown;

    return Column(
      children: [
        if (selectedName != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${AppStrings.selectedTicket}: $selectedName (ID: $_selectedTicketId)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canRun ? _runTicket : null,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(onCooldown ? Icons.timer_outlined : Icons.play_arrow, size: 20),
            label: Text(
              _running
                  ? AppStrings.runningTicket
                  : onCooldown
                      ? AppStrings.ticketCooldownCountdown(_cooldownRemaining)
                      : AppStrings.runTicket,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    final isFailed = _step == TicketStep.failed;
    final isDone = _step == TicketStep.complete;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isFailed
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : isDone
                  ? Colors.green.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepRow(TicketStep.chargeTicket, AppStrings.stepChargeTicket, theme),
            if (_autoLogout)
              _stepRow(TicketStep.logout, AppStrings.stepLogout, theme),
            if (_stepMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFailed
                      ? theme.colorScheme.errorContainer
                      : isDone
                          ? Colors.green.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _stepMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: isFailed
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepRow(TicketStep step, String label, ThemeData theme) {
    IconData icon;
    Color? color;

    if (_step == TicketStep.failed && _step.index <= step.index) {
      icon = _step == step ? Icons.error : Icons.circle_outlined;
      color = _step == step ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    } else if (_step.index > step.index) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_step == step) {
      icon = Icons.sync;
      color = theme.colorScheme.primary;
    } else {
      icon = Icons.circle_outlined;
      color = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _step.index >= step.index
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: _step == step ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/user_kaleidx_scope.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';

/// 万花筒专区：发现新的宿命之门 + 获取门的钥匙。
///
/// 两个动作落在 `upsertUserAll.userKaleidxScopeList` 同一行的两个布尔位上
/// （`isGateFound` / `isKeyFound`）。钥匙不走 `userItemList`：
/// `ExportUserItems` 从不输出 itemKind 15，下行也没有读它的路径。
class KaleidxScopePage extends StatefulWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final Future<void> Function()? onExitToTitle;

  const KaleidxScopePage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
  });

  @override
  State<KaleidxScopePage> createState() => _KaleidxScopePageState();
}

enum _Step { idle, fetchData, upload, logout, complete, failed }

class _KaleidxScopePageState extends State<KaleidxScopePage> {
  /// 与其它高危功能一致：不写真实成绩，playlog 用同一条占位记录。
  static const int _placeholderMusicId = 11538;

  final _gateIdController = TextEditingController();
  final List<int> _pending = [];

  bool _discover = true;
  bool _giveKey = false;

  Map<String, Map<String, dynamic>> _userAllData = const {};
  List<UserKaleidxScopeBean> _serverScopes = const [];

  bool _loading = false;
  bool _running = false;
  bool _autoLogout = true;
  _Step _step = _Step.idle;
  String _stepMessage = '';

  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  bool get _loggedIn => widget.loginDateTime != null;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void didUpdateWidget(covariant KaleidxScopePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _gateIdController.dispose();
    super.dispose();
  }

  void _syncCooldown() {
    _cooldownTimer?.cancel();
    final loginDateTime = widget.loginDateTime;
    if (loginDateTime == null) {
      setState(() => _cooldownRemaining = 0);
      return;
    }
    setState(() => _cooldownRemaining = _computeRemaining(loginDateTime));
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
    final remaining =
        AppStrings.ticketCooldownSeconds - (nowSec - loginDateTime);
    return remaining < 0 ? 0 : remaining;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addPending() {
    final id = int.tryParse(_gateIdController.text.trim()) ?? -1;
    if (id <= 0) {
      _snack(AppStrings.kaleidxNeedGateId);
      return;
    }
    if (_pending.contains(id)) {
      _snack(AppStrings.kaleidxGateIdDuplicated);
      return;
    }
    setState(() {
      _pending.add(id);
      _gateIdController.clear();
    });
  }

  UserKaleidxScopeBean? _serverRow(int gateId) {
    for (final row in _serverScopes) {
      if (row.gateId == gateId) return row;
    }
    return null;
  }

  /// 整行替换，所以已存在的门必须拿服务器原行做底，只改那两个布尔位。
  List<UserKaleidxScopeBean> _buildRows() {
    return [
      for (final id in _pending)
        _serverRow(id)?.withActions(discover: _discover, giveKey: _giveKey) ??
            UserKaleidxScopeBean.discovered(id, giveKey: _giveKey),
    ];
  }

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() => _loading = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final results = await Future.wait([
        service.fetchUserAllData(widget.userId),
        service.getUserKaleidxScopes(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _userAllData = results[0] as Map<String, Map<String, dynamic>>;
        _serverScopes = results[1] as List<UserKaleidxScopeBean>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('${AppStrings.loadFailed}: $e');
    }
  }

  Future<void> _run() async {
    if (!TitleServerConfigHolder().isConfigured) {
      _snack(AppStrings.ticketNotConfigured);
      return;
    }
    final loginDateTime = widget.loginDateTime;
    final loginId = widget.loginId;
    if (loginDateTime == null || loginId == null) {
      _snack(AppStrings.kaleidxNotLoggedIn);
      return;
    }
    if (_cooldownRemaining > 0) {
      _snack(AppStrings.kaleidxCooldownNotice(_cooldownRemaining));
      return;
    }
    if (_pending.isEmpty) {
      _snack(AppStrings.kaleidxNeedGateId);
      return;
    }
    if (!_discover && !_giveKey) {
      _snack(AppStrings.kaleidxNeedAction);
      return;
    }

    setState(() => _running = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final builder = UserAllPayloadBuilder(config);

      var data = _userAllData;
      if (data.isEmpty || _serverScopes.isEmpty) {
        _updateStep(_Step.fetchData);
        final results = await Future.wait([
          service.fetchUserAllData(widget.userId),
          service.getUserKaleidxScopes(widget.userId),
        ]);
        data = results[0] as Map<String, Map<String, dynamic>>;
        if (mounted) {
          setState(() {
            _userAllData = data;
            _serverScopes = results[1] as List<UserKaleidxScopeBean>;
          });
        }
      }

      _updateStep(_Step.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: _placeholderMusicData(),
        generalUserInfo: data,
      );

      final rows = _buildRows();
      // 每一位 '1' 插入 / '0' 更新，判据是服务器有没有同 gateId 的行。
      final flags = [
        for (final row in rows) _serverRow(row.gateId) == null ? '1' : '0',
      ].join();
      builder.applyKaleidxScopePatch(
        packet,
        scopes: [for (final row in rows) row.toWireJson()],
        newFlags: flags,
      );

      await service.upsertUserAll(packet, widget.userId);
      _updateStep(_Step.complete, await _verify(service));

      if (_autoLogout && widget.onExitToTitle != null) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _updateStep(_Step.logout, AppStrings.exitingToTitle);
        await widget.onExitToTitle!();
      }
    } on TitleApiException catch (e) {
      _updateStep(_Step.failed, e.message);
    } catch (e) {
      _updateStep(_Step.failed, '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<String> _verify(TitleApiService service) async {
    final requested = List<int>.from(_pending);
    List<UserKaleidxScopeBean> rows;
    try {
      rows = await service.getUserKaleidxScopes(widget.userId);
    } catch (e) {
      return AppStrings.kaleidxVerifyFailed('$e');
    }
    if (mounted) setState(() => _serverScopes = rows);

    final saved = rows.where((r) => requested.contains(r.gateId));
    final missing = requested
        .where((id) => !rows.any((r) => r.gateId == id))
        .toList();
    if (missing.isNotEmpty) {
      return AppStrings.kaleidxNotSaved(missing.join(' / '));
    }
    return AppStrings.kaleidxVerified(saved.length);
  }

  Map<String, dynamic> _placeholderMusicData() => {
    'musicId': _placeholderMusicId,
    'level': 0,
    'playCount': 1,
    'achievement': 0,
    'comboStatus': 0,
    'syncStatus': 0,
    'deluxscoreMax': 0,
    'scoreRank': 0,
    'extNum1': 0,
  };

  void _updateStep(_Step step, [String? message]) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _stepMessage = message ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.kaleidxFeatureTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: responsiveBody(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loggedIn)
                _notice(theme, AppStrings.kaleidxNotLoggedIn, error: true),
              if (_loggedIn && _cooldownRemaining > 0)
                _notice(
                  theme,
                  AppStrings.kaleidxCooldownNotice(_cooldownRemaining),
                ),
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleRow(
                      theme,
                      Icons.science_outlined,
                      AppStrings.kaleidxFeatureTitle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.kaleidxFeatureDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _inputCard(theme),
              const SizedBox(height: 12),
              _fetchCard(theme),
              const SizedBox(height: 12),
              _autoLogoutToggle(theme),
              const SizedBox(height: 12),
              _runButton(theme),
              if (_step != _Step.idle) ...[
                const SizedBox(height: 16),
                _progressCard(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(ThemeData theme, String text, {bool error = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: error
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: error
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _titleRow(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? () => onChanged(!value) : null,
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
          ),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _inputCard(ThemeData theme) {
    final enabled = !_running;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _gateIdController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.kaleidxGateIdLabel,
              hintText: AppStrings.kaleidxGateIdHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled ? _addPending : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(AppStrings.listAddButton),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _checkRow(
            label: AppStrings.kaleidxActionDiscover,
            value: _discover,
            enabled: enabled,
            onChanged: (v) => setState(() => _discover = v),
          ),
          _checkRow(
            label: AppStrings.kaleidxActionKey,
            value: _giveKey,
            enabled: enabled,
            onChanged: (v) => setState(() => _giveKey = v),
          ),
          if (_giveKey) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.kaleidxKeyNeedsGate,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final id in _pending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '#$id  ${_stateLabelFor(id)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          if (_pending.isEmpty)
            Text(
              AppStrings.kaleidxPendingEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _stateLabelFor(int gateId) {
    final row = _serverRow(gateId);
    if (row == null) {
      return _userAllData.isEmpty
          ? ''
          : AppStrings.kaleidxGateState(false, false, false);
    }
    return AppStrings.kaleidxGateState(
      row.isGateFound,
      row.isKeyFound,
      row.isClear,
    );
  }

  Widget _fetchCard(ThemeData theme) {
    final hasData = _userAllData.isNotEmpty;
    return _card(
      theme,
      child: Row(
        children: [
          Icon(
            hasData ? Icons.check_circle : Icons.download,
            size: 18,
            color: hasData ? Colors.green : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasData
                  ? '${AppStrings.kaleidxFetched} (${_serverScopes.length})'
                  : AppStrings.kaleidxNoData,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasData
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: _loading || _running ? null : _fetchData,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                _loading
                    ? AppStrings.travelPartnerFetching
                    : AppStrings.kaleidxFetchData,
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
    );
  }

  Widget _autoLogoutToggle(ThemeData theme) {
    final enabled = widget.onExitToTitle != null && !_running;
    return _card(
      theme,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? () => setState(() => _autoLogout = !_autoLogout) : null,
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
                AppStrings.autoLogoutAndExit,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _running || !_loggedIn ? null : _run,
        icon: _running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_open_outlined, size: 20),
        label: Text(
          _running ? AppStrings.kaleidxRunning : AppStrings.kaleidxRun,
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _progressCard(ThemeData theme) {
    final isFailed = _step == _Step.failed;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepRow(theme, _Step.fetchData, AppStrings.kaleidxStepFetch),
          _stepRow(theme, _Step.upload, AppStrings.kaleidxStepUpload),
          if (_autoLogout) _stepRow(theme, _Step.logout, AppStrings.stepLogout),
          if (_stepMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFailed
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
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
        ],
      ),
    );
  }

  Widget _stepRow(ThemeData theme, _Step step, String label) {
    final order = [_Step.fetchData, _Step.upload, _Step.logout, _Step.complete];
    final current = _step == _Step.failed ? _Step.upload : _step;
    final done = order.indexOf(current) > order.indexOf(step);
    final active = _step == step;

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


import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/user_kaleidx_scope.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/step_progress.dart';

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

class _KaleidxScopePageState extends State<KaleidxScopePage>
    with CooldownMixin<KaleidxScopePage> {
  final _gateIdController = TextEditingController();
  final List<int> _pending = [];

  bool _discover = true;
  bool _giveKey = false;

  Map<String, Map<String, dynamic>> _userAllData = const {};
  List<UserKaleidxScopeBean> _serverScopes = const [];

  bool _loading = false;
  bool _running = false;
  bool _autoLogout = true;
  RiskStep _step = RiskStep.idle;
  String _stepMessage = '';

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  @override
  void dispose() {
    _gateIdController.dispose();
    super.dispose();
  }

  void _snack(String message) => context.showSnack(message);

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
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
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
    if (cooldownRemaining > 0) {
      _snack(AppStrings.kaleidxCooldownNotice(cooldownRemaining));
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
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
      final builder = UserAllPayloadBuilder(service.config);

      var data = _userAllData;
      if (data.isEmpty || _serverScopes.isEmpty) {
        _updateStep(RiskStep.fetchData);
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

      _updateStep(RiskStep.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: UserAllPayloadBuilder.placeholderMusicData(),
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
      _updateStep(RiskStep.complete, await _verify(service));

      if (_autoLogout && widget.onExitToTitle != null) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _updateStep(RiskStep.logout, AppStrings.exitingToTitle);
        await widget.onExitToTitle!();
      }
    } on TitleApiException catch (e) {
      _updateStep(RiskStep.failed, e.message);
    } catch (e) {
      _updateStep(RiskStep.failed, '$e');
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

  void _updateStep(RiskStep step, [String? message]) {
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
              if (!isLoggedIn)
                const AppNotice(AppStrings.kaleidxNotLoggedIn, error: true),
              if (isLoggedIn && cooldownRemaining > 0)
                AppNotice(
                  AppStrings.kaleidxCooldownNotice(cooldownRemaining),
                ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      icon: Icons.science_outlined,
                      title: AppStrings.kaleidxFeatureTitle,
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
              AutoLogoutToggle(
                value: _autoLogout,
                enabled: widget.onExitToTitle != null && !_running,
                onChanged: (v) => setState(() => _autoLogout = v),
              ),
              const SizedBox(height: 12),
              _runButton(theme),
              if (_step != RiskStep.idle) ...[
                const SizedBox(height: 16),
                StepProgressCard(
                  step: _step,
                  message: _stepMessage,
                  steps: [
                    (RiskStep.fetchData, AppStrings.kaleidxStepFetch),
                    (RiskStep.upload, AppStrings.kaleidxStepUpload),
                    if (_autoLogout) (RiskStep.logout, AppStrings.stepLogout),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
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
    return AppCard(
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
    return AppCard(
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

  Widget _runButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _running || !isLoggedIn ? null : _run,
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
}

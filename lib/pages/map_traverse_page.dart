
import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/step_progress.dart';

/// 一键跑图：把选中的区域标记为已完成。
///
/// 依据反编译客户端：
/// - 区域进度是 `upsertUserAll.userMapList`，行结构见 `Net/VO/Mai2/UserMap.cs`
///   `{mapId, distance, isLock, isClear, isComplete, unlockFlag}`，主键 mapId。
/// - `MapMaster.CreateUserDataMapList`（Util/MapMaster.cs:509-543）用 `distance`
///   与该区域的 ReleaseFlag / End 里程针比较，**重算** isClear / isComplete，
///   没有对应针时甚至强制写回 false。所以只发 flag 会被冲掉，必须把
///   `distance` 推过 End 针——这里直接给 `UserMapData.MaxDistance`。
/// - `unlockFlag` 语义是反的：`IsFinishedOpening ? 0 : 1`。
/// - `isLock` 客户端不回读（`ConvertUserMap` 从不读它）。
class MapTraversePage extends StatefulWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final Future<void> Function()? onExitToTitle;

  const MapTraversePage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
  });

  @override
  State<MapTraversePage> createState() => _MapTraversePageState();
}

class _MapTraversePageState extends State<MapTraversePage>
    with CooldownMixin<MapTraversePage> {
  final _mapIdController = TextEditingController();
  final List<int> _pending = [];

  Map<String, Map<String, dynamic>> _userAllData = const {};
  Set<int>? _serverMapIds;
  List<Map<String, dynamic>> _serverMaps = const [];

  bool _loading = false;
  bool _running = false;
  bool _autoLogout = true;
  RiskStep _step = RiskStep.idle;
  String _stepMessage = '';

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  @override
  void dispose() {
    _mapIdController.dispose();
    super.dispose();
  }

  void _snack(String message) => context.showSnack(message);

  void _addPending() {
    final id = int.tryParse(_mapIdController.text.trim()) ?? -1;
    if (id <= 0) {
      _snack(AppStrings.mapNeedMapId);
      return;
    }
    if (_pending.contains(id)) {
      _snack(AppStrings.listDuplicate);
      return;
    }
    setState(() {
      _pending.add(id);
      _mapIdController.clear();
    });
  }

  void _applyServerMaps(List<Map<String, dynamic>> rows) {
    _serverMaps = rows;
    _serverMapIds = rows
        .map((e) => (e['mapId'] as num?)?.toInt() ?? 0)
        .where((e) => e != 0)
        .toSet();
  }

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() => _loading = true);

    try {
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
      final results = await Future.wait([
        service.fetchUserAllData(widget.userId),
        service.getUserMaps(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _userAllData = results[0] as Map<String, Map<String, dynamic>>;
        _applyServerMaps(results[1] as List<Map<String, dynamic>>);
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
      _snack(AppStrings.mapNotLoggedIn);
      return;
    }
    if (cooldownRemaining > 0) {
      _snack(AppStrings.mapCooldownNotice(cooldownRemaining));
      return;
    }
    if (_pending.isEmpty) {
      _snack(AppStrings.mapNeedMapId);
      return;
    }

    setState(() => _running = true);

    try {
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
      final builder = UserAllPayloadBuilder(service.config);

      var data = _userAllData;
      var serverIds = _serverMapIds;
      if (data.isEmpty || serverIds == null) {
        _updateStep(RiskStep.fetchData);
        final results = await Future.wait([
          service.fetchUserAllData(widget.userId),
          service.getUserMaps(widget.userId),
        ]);
        data = results[0] as Map<String, Map<String, dynamic>>;
        if (mounted) setState(() => _userAllData = data);
        _applyServerMaps(results[1] as List<Map<String, dynamic>>);
        serverIds = _serverMapIds!;
      }

      _updateStep(RiskStep.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: UserAllPayloadBuilder.placeholderMusicData(),
        generalUserInfo: data,
      );

      // isNewMapList 与 userMapList 一一对齐，每位 '1' 新增 / '0' 更新，
      // 判据是服务器是否已有同 mapId 的行（VOExtensions.BuildListData）。
      final maps = [
        for (final id in _pending) UserAllPayloadBuilder.completedMap(id),
      ];
      final flags = [
        for (final id in _pending) serverIds.contains(id) ? '0' : '1',
      ].join();
      builder.applyMapPatch(packet, maps: maps, newFlags: flags);

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

  /// 回读区分「服务器没写入 userMapList」和「写入了但游戏里仍显示未完成」。
  Future<String> _verify(TitleApiService service) async {
    final requested = List<int>.from(_pending);
    List<Map<String, dynamic>> rows;
    try {
      rows = await service.getUserMaps(widget.userId);
    } catch (e) {
      return AppStrings.mapVerifyFailed('$e');
    }
    if (mounted) setState(() => _applyServerMaps(rows));

    final saved = _serverMapIds ?? <int>{};
    final missing = requested.where((id) => !saved.contains(id)).toList();
    if (missing.isNotEmpty) {
      return AppStrings.mapNotSaved(missing.join(' / '));
    }
    return AppStrings.mapVerified(requested.length);
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
      appBar: AppBar(title: const Text(AppStrings.mapFeatureTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: responsiveBody(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isLoggedIn)
                const AppNotice(AppStrings.mapNotLoggedIn, error: true),
              if (isLoggedIn && cooldownRemaining > 0)
                AppNotice(AppStrings.mapCooldownNotice(cooldownRemaining)),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      icon: Icons.map_outlined,
                      title: AppStrings.mapFeatureTitle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.mapFeatureDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.mapCollectiblesNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
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
                    (RiskStep.fetchData, AppStrings.mapStepFetch),
                    (RiskStep.upload, AppStrings.mapStepUpload),
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

  Widget _inputCard(ThemeData theme) {
    final enabled = !_running;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _mapIdController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.mapIdLabel,
              hintText: AppStrings.mapIdHint,
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
          const SizedBox(height: 10),
          Text(
            _pending.isEmpty
                ? AppStrings.mapPendingEmpty
                : _pending.map((e) => '#$e').join('  '),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: _pending.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fetchCard(ThemeData theme) {
    final hasData = _serverMapIds != null;
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
                  ? '${AppStrings.mapFetched} (${_serverMaps.length})'
                  : AppStrings.mapNoData,
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
                    : AppStrings.mapFetchData,
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
            : const Icon(Icons.flag_outlined, size: 20),
        label: Text(
          _running ? AppStrings.mapRunning : AppStrings.mapRun,
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

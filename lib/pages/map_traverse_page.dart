import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';

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

enum _Step { idle, fetchData, upload, logout, complete, failed }

class _MapTraversePageState extends State<MapTraversePage> {
  /// 与其它高危功能一致：不写真实成绩，playlog 用同一条占位记录。
  static const int _placeholderMusicId = 11538;

  final _mapIdController = TextEditingController();
  final List<int> _pending = [];

  Map<String, Map<String, dynamic>> _userAllData = const {};
  Set<int>? _serverMapIds;
  List<Map<String, dynamic>> _serverMaps = const [];

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
  void didUpdateWidget(covariant MapTraversePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _mapIdController.dispose();
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
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
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
    if (_cooldownRemaining > 0) {
      _snack(AppStrings.mapCooldownNotice(_cooldownRemaining));
      return;
    }
    if (_pending.isEmpty) {
      _snack(AppStrings.mapNeedMapId);
      return;
    }

    setState(() => _running = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final builder = UserAllPayloadBuilder(config);

      var data = _userAllData;
      var serverIds = _serverMapIds;
      if (data.isEmpty || serverIds == null) {
        _updateStep(_Step.fetchData);
        final results = await Future.wait([
          service.fetchUserAllData(widget.userId),
          service.getUserMaps(widget.userId),
        ]);
        data = results[0] as Map<String, Map<String, dynamic>>;
        if (mounted) setState(() => _userAllData = data);
        _applyServerMaps(results[1] as List<Map<String, dynamic>>);
        serverIds = _serverMapIds!;
      }

      _updateStep(_Step.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: _placeholderMusicData(),
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
      appBar: AppBar(title: const Text(AppStrings.mapFeatureTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: responsiveBody(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loggedIn)
                _notice(theme, AppStrings.mapNotLoggedIn, error: true),
              if (_loggedIn && _cooldownRemaining > 0)
                _notice(theme, AppStrings.mapCooldownNotice(_cooldownRemaining)),
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleRow(
                      theme,
                      Icons.map_outlined,
                      AppStrings.mapFeatureTitle,
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

  Widget _inputCard(ThemeData theme) {
    final enabled = !_running;
    return _card(
      theme,
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

  Widget _progressCard(ThemeData theme) {
    final isFailed = _step == _Step.failed;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepRow(theme, _Step.fetchData, AppStrings.mapStepFetch),
          _stepRow(theme, _Step.upload, AppStrings.mapStepUpload),
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

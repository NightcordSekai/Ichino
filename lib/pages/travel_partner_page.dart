import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/user_character.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';

/// 旅行伙伴页：发放角色 + 编组出战槽位。
///
/// 依据反编译客户端：
/// - 旅行伙伴是 `ItemKind.Character = 9`，与「搭档」`Partner = 10` 是两种东西。
/// - 客户端的 `ExportUserItems()` 不导出 itemKind 9；角色的拥有状态走
///   `upsertUserAll.userCharacterList`（`{characterId, level, awakening, useCount}`，
///   主键 characterId，见 VOExtensions.cs:265）。
/// - 出战编组是 `UserDetail.charaSlot`，`int[5]`，槽 0 为队长
///   （CharactorSlotController.cs:27）。
class TravelPartnerPage extends StatefulWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;

  /// 完成后退出登录并返回标题页，由 HomePage 提供。
  final Future<void> Function()? onExitToTitle;

  const TravelPartnerPage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
  });

  @override
  State<TravelPartnerPage> createState() => _TravelPartnerPageState();
}

enum _Step { idle, fetchData, upload, logout, complete, failed }

class _TravelPartnerPageState extends State<TravelPartnerPage> {
  /// 与解锁/收藏品一致：这些操作不写真实成绩，playlog 沿用同一条占位记录。
  static const int _placeholderMusicId = 11538;

  final _grantIdController = TextEditingController();

  List<UserCharacterBean> _owned = const [];
  Map<String, Map<String, dynamic>> _userAllData = const {};
  final List<int> _pendingGrant = [];
  List<int> _slots = normalizeCharaSlot(const []);

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
  void didUpdateWidget(covariant TravelPartnerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _grantIdController.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isAvailable(int characterId) =>
      characterId != 0 &&
      (_owned.any((c) => c.characterId == characterId) ||
          _pendingGrant.contains(characterId));

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() => _loading = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final results = await Future.wait([
        service.getUserCharacters(widget.userId),
        service.fetchUserAllData(widget.userId),
      ]);
      if (!mounted) return;

      final owned = results[0] as List<UserCharacterBean>;
      final all = results[1] as Map<String, Map<String, dynamic>>;
      final userData =
          (all['GetUserDataApi']?['userData'] as Map<String, dynamic>?) ??
          const {};
      final slots = (userData['charaSlot'] as List<dynamic>? ?? const [])
          .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
          .toList();

      setState(() {
        _owned = owned;
        _userAllData = all;
        _slots = normalizeCharaSlot(slots);
        // 槽位里引用了但列表没有的角色，保留为可选，避免下拉框丢项。
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('${AppStrings.loadFailed}: $e');
    }
  }

  void _addGrant() {
    final id = int.tryParse(_grantIdController.text.trim()) ?? -1;
    if (id <= 0) {
      _snack(AppStrings.travelPartnerNeedCharacterId);
      return;
    }
    if (_owned.any((c) => c.characterId == id)) {
      _snack(AppStrings.travelPartnerAlreadyOwned);
      return;
    }
    if (_pendingGrant.contains(id)) {
      _snack(AppStrings.listDuplicate);
      return;
    }
    setState(() {
      _pendingGrant.add(id);
      _grantIdController.clear();
    });
  }

  /// 一键把槽 0 的旅行伙伴复制到其他四个槽位。
  void _copySlot0ToOthers() {
    final leader = _slots.isNotEmpty ? _slots[0] : 0;
    if (leader == 0) {
      _snack(AppStrings.travelPartnerCopyNeedSlot0);
      return;
    }
    if (!_isAvailable(leader)) {
      _snack(AppStrings.travelPartnerNotOwnedHint);
      return;
    }
    setState(() {
      _slots = normalizeCharaSlot([for (var i = 0; i < 5; i++) leader]);
    });
  }

  String? _validate() {
    if (_pendingGrant.isEmpty && _userAllData.isEmpty) {
      return AppStrings.travelPartnerNoData;
    }
    if (_userAllData.isEmpty) return AppStrings.travelPartnerNoData;
    for (final slot in _slots) {
      if (slot != 0 && !_isAvailable(slot)) {
        return AppStrings.travelPartnerNotOwnedHint;
      }
    }
    return null;
  }

  Future<void> _run() async {
    if (!TitleServerConfigHolder().isConfigured) {
      _snack(AppStrings.ticketNotConfigured);
      return;
    }
    final loginDateTime = widget.loginDateTime;
    final loginId = widget.loginId;
    if (loginDateTime == null || loginId == null) {
      _snack(AppStrings.travelPartnerNotLoggedIn);
      return;
    }
    if (_cooldownRemaining > 0) {
      _snack(AppStrings.travelPartnerCooldownNotice(_cooldownRemaining));
      return;
    }
    final validationError = _validate();
    if (validationError != null) {
      _snack(validationError);
      return;
    }

    setState(() => _running = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final builder = UserAllPayloadBuilder(config);

      var data = _userAllData;
      if (data.isEmpty) {
        _updateStep(_Step.fetchData);
        data = await service.fetchUserAllData(widget.userId);
        if (mounted) setState(() => _userAllData = data);
      }

      _updateStep(_Step.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: _placeholderMusicData(),
        generalUserInfo: data,
      );

      if (_pendingGrant.isNotEmpty) {
        // 新角色给最小可用值；已拥有的不重发，避免把 level/awakening 打回。
        builder.applyCharacterListPatch(
          packet,
          characters: [
            for (final id in _pendingGrant)
              {'characterId': id, 'level': 1, 'awakening': 0, 'useCount': 0},
          ],
        );
      }
      builder.applyCharaSlotPatch(packet, charaSlot: _slots);

      await service.upsertUserAll(packet, widget.userId);

      _updateStep(_Step.complete, AppStrings.travelPartnerSuccess);

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
      appBar: AppBar(
        title: const Text(AppStrings.travelPartnerFeatureTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: responsiveBody(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loggedIn)
                _notice(
                  theme,
                  AppStrings.travelPartnerNotLoggedIn,
                  error: true,
                ),
              if (_loggedIn && _cooldownRemaining > 0)
                _notice(
                  theme,
                  AppStrings.travelPartnerCooldownNotice(_cooldownRemaining),
                ),
              _sectionCard(
                theme,
                icon: Icons.card_giftcard,
                title: AppStrings.travelPartnerFeatureDesc,
                children: const [],
              ),
              const SizedBox(height: 12),
              _fetchCard(theme),
              const SizedBox(height: 12),
              _grantCard(theme),
              const SizedBox(height: 12),
              _slotCard(theme),
              const SizedBox(height: 12),
              _ownedCard(theme),
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

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          ),
          ...children,
        ],
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

  Widget _fetchCard(ThemeData theme) {
    final hasData = _userAllData.isNotEmpty && _owned.isNotEmpty;
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
                  ? AppStrings.travelPartnerFetched
                  : AppStrings.travelPartnerNoData,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasData ? Colors.green : theme.colorScheme.onSurfaceVariant,
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
                    : _userAllData.isNotEmpty
                        ? AppStrings.travelPartnerRefetch
                        : AppStrings.travelPartnerFetchData,
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

  Widget _grantCard(ThemeData theme) {
    final enabled = !_running;
    return _sectionCard(
      theme,
      icon: Icons.add_circle_outline,
      title: AppStrings.travelPartnerGrantTitle,
      children: [
        const SizedBox(height: 14),
        TextField(
          controller: _grantIdController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppStrings.travelPartnerCharacterIdLabel,
            hintText: AppStrings.travelPartnerCharacterIdHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: enabled ? _addGrant : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(AppStrings.listAddButton),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _pendingGrant.isEmpty
              ? AppStrings.travelPartnerGrantEmpty
              : _pendingGrant.map((e) => '#$e').join('  '),
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: _pendingGrant.isEmpty
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _slotCard(ThemeData theme) {
    // 下拉选项 = 已拥有 ∪ 待发放 ∪ 当前槽位已有值。
    final optionIds = <int>{
      ..._owned.map((c) => c.characterId),
      ..._pendingGrant,
      ..._slots.where((e) => e != 0),
    }.toList()
      ..sort();

    return _sectionCard(
      theme,
      icon: Icons.groups_outlined,
      title: AppStrings.travelPartnerSlotTitle,
      children: [
        const SizedBox(height: 14),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<int>(
              initialValue: _slots[i],
              decoration: InputDecoration(
                labelText: AppStrings.travelPartnerSlotLabel(i),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(
                    AppStrings.travelPartnerSlotNone,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                for (final id in optionIds)
                  DropdownMenuItem(value: id, child: Text('#$id')),
              ],
              onChanged: _running
                  ? null
                  : (v) => setState(() {
                      final next = [..._slots];
                      next[i] = v ?? 0;
                      _slots = next;
                    }),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _running ? null : _copySlot0ToOthers,
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text(AppStrings.travelPartnerCopySlot0),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ownedCard(ThemeData theme) {
    return _sectionCard(
      theme,
      icon: Icons.workspace_premium_outlined,
      title:
          '${AppStrings.travelPartnerOwnedTitle} (${_owned.length})',
      children: [
        const SizedBox(height: 14),
        if (_owned.isEmpty)
          Text(
            AppStrings.travelPartnerOwnedEmpty,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in _owned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${c.characterId} Lv${c.level}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
      ],
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
            : const Icon(Icons.send, size: 20),
        label: Text(
          _running ? AppStrings.travelPartnerRunning : AppStrings.travelPartnerRun,
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
          _stepRow(theme, _Step.fetchData, AppStrings.travelPartnerStepFetch),
          _stepRow(theme, _Step.upload, AppStrings.travelPartnerStepUpload),
          if (_autoLogout)
            _stepRow(theme, _Step.logout, AppStrings.stepLogout),
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


import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/user_character.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/step_progress.dart';

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

class _TravelPartnerPageState extends State<TravelPartnerPage>
    with CooldownMixin<TravelPartnerPage> {
  final _grantIdController = TextEditingController();

  /// 每个出战槽位一个等级输入框，留空表示不改该角色的等级。
  final _slotLevelControllers = List<TextEditingController>.generate(
    5,
    (_) => TextEditingController(),
  );

  List<UserCharacterBean> _owned = const [];
  Map<String, Map<String, dynamic>> _userAllData = const {};
  final List<int> _pendingGrant = [];
  List<int> _slots = normalizeCharaSlot(const []);

  bool _loading = false;
  bool _running = false;
  bool _autoLogout = true;
  RiskStep _step = RiskStep.idle;
  String _stepMessage = '';

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  @override
  void dispose() {
    _grantIdController.dispose();
    for (final c in _slotLevelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String message) => context.showSnack(message);

  bool _isAvailable(int characterId) =>
      characterId != 0 &&
      (_owned.any((c) => c.characterId == characterId) ||
          _pendingGrant.contains(characterId));

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() => _loading = true);

    try {
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
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
      // 五个槽位这时都是同一个角色，等级跟着一起复制才对得上。
      final leaderLevel = _slotLevelControllers[0].text;
      for (var i = 1; i < 5; i++) {
        _slotLevelControllers[i].text = leaderLevel;
      }
    });
  }

  /// 槽位上填了的等级 -> characterId -> level。同一角色占多个槽位时取最高的，
  /// 否则两个槽位填了不同等级就没有确定答案。
  Map<int, int> _slotLevelsById() {
    final result = <int, int>{};
    for (var i = 0; i < 5; i++) {
      final id = _slots[i];
      final level = int.tryParse(_slotLevelControllers[i].text.trim());
      if (id == 0 || level == null) continue;
      final existing = result[id];
      if (existing == null || level > existing) result[id] = level;
    }
    return result;
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
    const min = UserAllPayloadBuilder.minCharacterLevel;
    const max = UserAllPayloadBuilder.maxCharacterLevel;
    for (final level in _slotLevelsById().values) {
      if (level < min || level > max) return AppStrings.travelPartnerLevelInvalid;
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
    if (cooldownRemaining > 0) {
      _snack(AppStrings.travelPartnerCooldownNotice(cooldownRemaining));
      return;
    }
    final validationError = _validate();
    if (validationError != null) {
      _snack(validationError);
      return;
    }

    setState(() => _running = true);

    try {
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
      final builder = UserAllPayloadBuilder(service.config);

      var data = _userAllData;
      if (data.isEmpty) {
        _updateStep(RiskStep.fetchData);
        data = await service.fetchUserAllData(widget.userId);
        if (mounted) setState(() => _userAllData = data);
      }

      _updateStep(RiskStep.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: UserAllPayloadBuilder.placeholderMusicData(),
        generalUserInfo: data,
      );

      final levels = _slotLevelsById();
      final grantRows = [
        for (final id in _pendingGrant)
          {
            // 新角色默认最小可用值；槽位上填了等级就顺手带上，省一次操作。
            'characterId': id,
            'level': UserAllPayloadBuilder.clampCharacterLevel(
              levels[id] ?? 1,
            ),
            'awakening': 0,
            'useCount': 0,
          },
      ];
      // 已拥有且槽位要求改等级的，发 isNew='0' 的更新行。必须带上原有
      // useCount / awakening，否则整行被覆盖会把使用次数清零。
      final ownedById = {for (final c in _owned) c.characterId: c};
      final levelRows = <Map<String, dynamic>>[];
      for (final entry in levels.entries) {
        if (_pendingGrant.contains(entry.key)) continue;
        final owned = ownedById[entry.key];
        if (owned == null) continue;
        final level = UserAllPayloadBuilder.clampCharacterLevel(entry.value);
        if (level == owned.level) continue;
        levelRows.add(owned.copyWith(level: level).toWireJson());
      }
      if (grantRows.isNotEmpty || levelRows.isNotEmpty) {
        builder.applyCharacterListPatch(
          packet,
          characters: [...grantRows, ...levelRows],
          newFlags: '${'1' * grantRows.length}${'0' * levelRows.length}',
        );
      }
      builder.applyCharaSlotPatch(packet, charaSlot: _slots);

      await service.upsertUserAll(packet, widget.userId);

      // 两种失败在返回值上完全一样（returnCode 都是 1），只能靠回读区分：
      // 服务器没写入 userCharacterList，还是写入了但 ID 不在机台 Chara 表里
      // 被客户端 CharacterSelectProces 静默跳过。
      _updateStep(
        RiskStep.complete,
        _pendingGrant.isEmpty
            ? AppStrings.travelPartnerSuccess
            : await _verifyGranted(service),
      );

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

  Future<String> _verifyGranted(TitleApiService service) async {
    final requested = List<int>.from(_pendingGrant);
    List<UserCharacterBean> owned;
    try {
      owned = await service.getUserCharacters(widget.userId);
    } catch (e) {
      return AppStrings.travelPartnerVerifyFailed('$e');
    }
    if (mounted) setState(() => _owned = owned);

    final saved = owned.map((c) => c.characterId).toSet();
    final missing = requested.where((id) => !saved.contains(id)).toList();
    if (missing.isEmpty) return AppStrings.travelPartnerVerified(requested.length);
    return AppStrings.travelPartnerNotSaved(missing.join(' / '));
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
              if (!isLoggedIn)
                const AppNotice(
                  AppStrings.travelPartnerNotLoggedIn,
                  error: true,
                ),
              if (isLoggedIn && cooldownRemaining > 0)
                AppNotice(
                  AppStrings.travelPartnerCooldownNotice(cooldownRemaining),
                ),
              _sectionCard(
                theme,
                icon: Icons.card_giftcard,
                title: AppStrings.travelPartnerFeatureDesc,
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
                    (
                      RiskStep.fetchData,
                      AppStrings.travelPartnerStepFetch,
                    ),
                    (
                      RiskStep.upload,
                      AppStrings.travelPartnerStepUpload,
                    ),
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

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    List<Widget> children = const [],
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: icon, title: title),
          ...children,
        ],
      ),
    );
  }

  Widget _fetchCard(ThemeData theme) {
    final hasData = _userAllData.isNotEmpty && _owned.isNotEmpty;
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
        const SizedBox(height: 12),
        Text(
          AppStrings.travelPartnerIdRangeTitle,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.travelPartnerIdRangeBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (_pendingGrant.any(_isSuspectId)) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.travelPartnerIdUnknown,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// 客户端 `PlInformationProcess.AddDefaultCharacter` 里的默认发放清单，
  /// 是已知一定存在于机台 Chara 表的那批 ID。
  static const List<int> _knownCharacterIds = [
    101, 102, 103, 104, 105,
    201, 202, 203, 204, 205,
    301, 302, 303, 304, 305, 306,
    392, 393, 394, 395,
    401, 402, 403, 404, 405,
    501, 502, 503, 504, 505,
    601, 602, 603, 604, 605,
  ];

  bool _isSuspectId(int id) => !_knownCharacterIds.contains(id);

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
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
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
                if (_slots[i] != 0) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _slotLevelControllers[i],
                    enabled: !_running,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: AppStrings.travelPartnerLevelLabel,
                      hintText: AppStrings.travelPartnerLevelHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ..._levelHintLines(theme, _slotLevelControllers[i].text),
                ],
              ],
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

  /// 真实等级和界面等级不是一回事（`UserChara`：显示 = level % 10000、
  /// 转生 = level ~/ 10000），只在会混淆时才说明。
  List<Widget> _levelHintLines(ThemeData theme, String raw) {
    final level = int.tryParse(raw.trim());
    if (level == null || level < UserAllPayloadBuilder.minCharacterLevel) {
      return const [];
    }
    if (level <= 9999) return const [];
    return [
      const SizedBox(height: 4),
      Text(
        AppStrings.travelPartnerLevelConverted(level),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
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
}

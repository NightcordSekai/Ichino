import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';

/// Dart port of `eaquira/action/UnlockMusic.py`:
///
/// - 拉取 GetUserData/Extend/Option/Rating/Charge/Activity/MissionData
/// - 组装 UserAll payload (musicData 使用 eaquira settings 中的默认值)
/// - 附加道具 (userItemList / isNewItemList)
/// - UpsertUserAllApi 上传
/// - 可选自动 UserLogout
enum MusicRiskStep { idle, fetchData, upload, logout, complete, failed }

enum MusicRiskFeatureMode {
  /// 解锁歌曲与谱面 (itemKind 5/6/7)
  unlockMusic,

  /// 收藏品获取 (itemKind 1/2/3/10/11/12)
  collectibles,
}

/// 一行待提交的收藏品道具（对应 wire 上的 UserItem）。
class _PendingItem {
  final int kind;
  final int id;

  const _PendingItem(this.kind, this.id);
}

/// 一行待提交的歌曲解锁，展开成 itemKind 5/6/7 的若干行。
class _PendingMusic {
  final int musicId;
  final bool base;
  final bool master;
  final bool remaster;

  const _PendingMusic(this.musicId, this.base, this.master, this.remaster);

  bool get hasAnyOption => base || master || remaster;

  /// 难度由 itemKind 表达，不写在 musicDetail 上。
  List<int> get itemKinds => [
    if (base) 5,
    if (master) 6,
    if (remaster) 7,
  ];

  String get optionLabel => [
    if (base) '歌曲',
    if (master) 'Master',
    if (remaster) 'Re:Master',
  ].join('/');
}

class MusicRiskFeatureView extends StatefulWidget {
  final int userId;
  final String? cookies;

  /// `loginDateTime` 来自 HomePage 启动时执行的 UserLoginApi。
  /// 为 `null` 时表示当前未持有有效登录态（例如 isInherit 账号或登录失败）。
  final int? loginDateTime;

  /// UserLoginApi 返回的 loginId / lastLoginDate, 组装 UserAll 需要。
  final int? loginId;
  final String? lastLoginDate;

  /// 完成后自动退出登录并返回标题页时调用；由 HomePage 提供，
  /// 内部会等待结算、发 UserLogoutApi、重置会话并 pop 回主标题。
  final Future<void> Function()? onExitToTitle;

  final MusicRiskFeatureMode mode;
  final String featureTitle;
  final String featureDesc;

  const MusicRiskFeatureView({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.lastLoginDate,
    this.onExitToTitle,
    this.mode = MusicRiskFeatureMode.unlockMusic,
    required this.featureTitle,
    required this.featureDesc,
  });

  @override
  State<MusicRiskFeatureView> createState() => _MusicRiskFeatureViewState();
}

class _MusicRiskFeatureViewState extends State<MusicRiskFeatureView> {
  /// eaquira `settings.musicData` 默认歌曲 (Amber Chronicle)。
  static const int _defaultMusicId = 11538;

  // ── 解锁选项 (UnlockMusic) ──
  final _unlockMusicIdController = TextEditingController();
  bool _unlockMusic = false;
  bool _unlockMaster = false;
  bool _unlockRemaster = false;

  // ── 收藏品选项 (Collectibles) ──
  final _itemIdController = TextEditingController();
  int _itemKind = 3;

  // ── 待提交列表：userItemList 可以一次带多行 ──
  // 真客户端的 ExportUserItems() 就是把 Plate/Title/Icon/Partner/Frame/Ticket 与
  // MusicUnlock/Master/Remaster 各列表拼成多行 UserItem，BuildListData 再只发增量、
  // isNewItemList 一行一个字符。所以多行同类/异类混发是客户端自己的做法。
  final List<_PendingItem> _pendingItems = [];
  final List<_PendingMusic> _pendingMusics = [];

  // ── 运行状态 ──
  Map<String, Map<String, dynamic>>? _userAllData;
  bool _fetching = false;
  String? _fetchError;
  bool _running = false;
  bool _autoLogout = true;
  MusicRiskStep _step = MusicRiskStep.idle;
  String _stepMessage = '';
  String? _error;

  // ── 冷却 ──
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  bool get _isUnlock => widget.mode == MusicRiskFeatureMode.unlockMusic;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void didUpdateWidget(covariant MusicRiskFeatureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _unlockMusicIdController.dispose();
    _itemIdController.dispose();
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

  void _updateStep(MusicRiskStep step, [String? message]) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _stepMessage = message ?? '';
    });
  }

  int _unlockMusicId() =>
      int.tryParse(_unlockMusicIdController.text.trim()) ?? -1;

  int _itemId() => int.tryParse(_itemIdController.text.trim()) ?? -1;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 把当前输入框里的收藏品加入待提交列表。
  void _addItemToList() {
    final id = _itemId();
    if (id <= 0) {
      _snack(AppStrings.collectiblesNeedItemId);
      return;
    }
    if (_pendingItems.any((e) => e.kind == _itemKind && e.id == id)) {
      _snack(AppStrings.listDuplicate);
      return;
    }
    setState(() {
      _pendingItems.add(_PendingItem(_itemKind, id));
      _itemIdController.clear();
    });
  }

  /// 把当前输入框里的歌曲+勾选的难度加入待解锁列表。
  void _addMusicToList() {
    final id = _unlockMusicId();
    if (id <= 0) {
      _snack(AppStrings.unlockNeedMusicId);
      return;
    }
    if (!_unlockMusic && !_unlockMaster && !_unlockRemaster) {
      _snack(AppStrings.unlockNeedOption);
      return;
    }
    if (_pendingMusics.any((e) => e.musicId == id)) {
      _snack(AppStrings.listDuplicate);
      return;
    }
    setState(() {
      _pendingMusics.add(
        _PendingMusic(id, _unlockMusic, _unlockMaster, _unlockRemaster),
      );
      _unlockMusicIdController.clear();
      _unlockMusic = _unlockMaster = _unlockRemaster = false;
    });
  }

  /// eaquira UnlockMusic.py 使用 settings 中的默认 musicData。
  /// 解锁状态本身由 userItemList 的 itemKind 5/6/7 行表达，这里只保留一条
  /// 记录以维持 payload 形状，取列表首条歌曲 ID。
  Map<String, dynamic> _buildMusicData() {
    return {
      'musicId': _isUnlock
          ? (_pendingMusics.isNotEmpty
                ? _pendingMusics.first.musicId
                : _defaultMusicId)
          : _defaultMusicId,
      'level': 0,
      'playCount': 1,
      'achievement': 0,
      'comboStatus': 0,
      'syncStatus': 0,
      'deluxscoreMax': 0,
      'scoreRank': 0,
      'extNum1': 0,
    };
  }

  /// 汇总成 wire 上的 userItemList 行。
  List<Map<String, dynamic>> _buildUserItemList() {
    if (_isUnlock) {
      return [
        for (final music in _pendingMusics)
          for (final kind in music.itemKinds)
            {
              'itemKind': kind,
              'itemId': music.musicId,
              'stock': 1,
              'isValid': true,
            },
      ];
    }
    return [
      for (final item in _pendingItems)
        {
          'itemKind': item.kind,
          'itemId': item.id,
          'stock': 1,
          'isValid': true,
        },
    ];
  }

  String? _validateInputs() {
    if (_isUnlock) {
      if (_pendingMusics.isEmpty) return AppStrings.unlockNeedList;
      return null;
    }

    if (_pendingItems.isEmpty) return AppStrings.collectiblesNeedList;
    return null;
  }

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;

    setState(() {
      _fetching = true;
      _fetchError = null;
      _userAllData = null;
    });

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final data = await service.fetchUserAllData(widget.userId);
      if (!mounted) return;
      setState(() {
        _userAllData = data;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = e.toString();
        _fetching = false;
      });
    }
  }

  Future<void> _run() async {
    final validationError = _validateInputs();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
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
    final loginId = widget.loginId;
    if (loginDateTime == null || loginId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_notLoggedInMessage)),
      );
      return;
    }
    if (_cooldownRemaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cooldownNotice(_cooldownRemaining))),
      );
      return;
    }

    final config = TitleServerConfigHolder().config!;
    final service = TitleApiService(config, cookies: widget.cookies);

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      Map<String, Map<String, dynamic>> data = _userAllData ?? const {};
      if (data.isEmpty) {
        _updateStep(MusicRiskStep.fetchData);
        data = await service.fetchUserAllData(widget.userId);
        if (mounted) setState(() => _userAllData = data);
      }

      _updateStep(MusicRiskStep.upload);
      final musicData = _buildMusicData();
      final builder = UserAllPayloadBuilder(config);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: musicData,
        generalUserInfo: data,
      );

      builder.applyItemListPatch(packet, items: _buildUserItemList());
      if (_isUnlock) {
        builder.applyMusicDetailPatch(packet, musicData: musicData);
      }

      await service.upsertUserAll(packet, widget.userId);

      _updateStep(
        MusicRiskStep.complete,
        _isUnlock
            ? AppStrings.unlockMusicSuccess
            : AppStrings.collectiblesSuccess,
      );

      if (_autoLogout && widget.onExitToTitle != null) {
        // 让成功状态先显示一下，再交给 HomePage 结算、退登并 pop 回主标题。
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _updateStep(MusicRiskStep.logout, AppStrings.exitingToTitle);
        await widget.onExitToTitle!();
      }
    } on TitleApiException catch (e) {
      _updateStep(MusicRiskStep.failed, e.message);
      setState(() => _error = e.message);
    } catch (e) {
      _updateStep(MusicRiskStep.failed, e.toString());
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String get _notLoggedInMessage => _isUnlock
      ? AppStrings.unlockNotLoggedIn
      : AppStrings.collectiblesNotLoggedIn;

  String _cooldownNotice(int remaining) => _isUnlock
      ? AppStrings.unlockCooldownNotice(remaining)
      : AppStrings.collectiblesCooldownNotice(remaining);

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
            if (_isUnlock)
              _buildUnlockCard(theme)
            else
              _buildCollectiblesCard(theme),
            const SizedBox(height: 12),
            _buildFetchCard(theme),
            const SizedBox(height: 12),
            _buildAutoLogoutToggle(theme),
            const SizedBox(height: 12),
            _buildRunButton(theme),
            if (_step != MusicRiskStep.idle) ...[
              const SizedBox(height: 16),
              _buildProgressCard(theme),
            ],
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
              _notLoggedInMessage,
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
              _cooldownNotice(_cooldownRemaining),
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
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isUnlock ? Icons.lock_open : Icons.card_giftcard,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.featureTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.featureDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockCard(ThemeData theme) {
    final enabled = !_running;

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
            TextField(
              controller: _unlockMusicIdController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.unlockMusicIdLabel,
                hintText: AppStrings.unlockMusicIdHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 6),
            _buildUnlockCheckbox(
              theme,
              value: _unlockMusic,
              label: AppStrings.unlockMusicOption,
              enabled: enabled,
              onChanged: (v) => setState(() => _unlockMusic = v),
            ),
            _buildUnlockCheckbox(
              theme,
              value: _unlockMaster,
              label: AppStrings.unlockMasterOption,
              enabled: enabled,
              onChanged: (v) => setState(() => _unlockMaster = v),
            ),
            _buildUnlockCheckbox(
              theme,
              value: _unlockRemaster,
              label: AppStrings.unlockRemasterOption,
              enabled: enabled,
              onChanged: (v) => setState(() => _unlockRemaster = v),
            ),
            const SizedBox(height: 8),
            _buildAddButton(theme, onPressed: enabled ? _addMusicToList : null),
            _buildPendingList(
              theme,
              title: AppStrings.unlockPendingTitle,
              emptyHint: AppStrings.unlockPendingEmpty,
              count: _pendingMusics.length,
              rows: [
                for (var i = 0; i < _pendingMusics.length; i++)
                  _buildPendingRow(
                    theme,
                    leading: '#${_pendingMusics[i].musicId}',
                    trailing: _pendingMusics[i].optionLabel,
                    onRemove: () => setState(() => _pendingMusics.removeAt(i)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme, {VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: const Text(AppStrings.listAddButton),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList(
    ThemeData theme, {
    required String title,
    required String emptyHint,
    required int count,
    required List<Widget> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          '$title ($count)',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (count == 0)
          Text(
            emptyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...rows,
      ],
    );
  }

  Widget _buildPendingRow(
    ThemeData theme, {
    required String leading,
    required String trailing,
    required VoidCallback onRemove,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$leading  $trailing',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: AppStrings.listRemoveTooltip,
          onPressed: _running ? null : onRemove,
          color: theme.colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildUnlockCheckbox(
    ThemeData theme, {
    required bool value,
    required String label,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? () => onChanged(!value) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            ),
            Expanded(
              child: Text(
                label,
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

  Widget _buildCollectiblesCard(ThemeData theme) {
    final enabled = !_running;

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
            _buildDropdown(
              value: _itemKind,
              label: AppStrings.collectiblesItemKindLabel,
              items: [
                for (final kind in AppStrings.collectiblesItemKinds)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(
                      '${AppStrings.collectiblesItemKindName(kind)} ($kind)',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _itemKind = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _itemIdController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.collectiblesItemIdLabel,
                hintText: AppStrings.collectiblesItemIdHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 8),
            _buildAddButton(theme, onPressed: enabled ? _addItemToList : null),
            _buildPendingList(
              theme,
              title: AppStrings.collectiblesPendingTitle,
              emptyHint: AppStrings.collectiblesPendingEmpty,
              count: _pendingItems.length,
              rows: [
                for (var i = 0; i < _pendingItems.length; i++)
                  _buildPendingRow(
                    theme,
                    leading:
                        '${AppStrings.collectiblesItemKindName(_pendingItems[i].kind)} (${_pendingItems[i].kind})',
                    trailing: '#${_pendingItems[i].id}',
                    onRemove: () => setState(() => _pendingItems.removeAt(i)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFetchCard(ThemeData theme) {
    final hasData = _userAllData != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasData
              ? Colors.green.withValues(alpha: 0.5)
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
                Icon(
                  hasData ? Icons.check_circle : Icons.download,
                  size: 18,
                  color: hasData ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasData
                        ? AppStrings.unlockFetched
                        : AppStrings.unlockNoData,
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
                    onPressed: _fetching || _running ? null : _fetchData,
                    icon: _fetching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      _fetching
                          ? AppStrings.unlockFetching
                          : hasData
                              ? AppStrings.unlockRefetch
                              : AppStrings.unlockFetchData,
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
            if (_fetchError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fetchError!,
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

  Widget _buildAutoLogoutToggle(ThemeData theme) {
    final enabled = widget.onExitToTitle != null && !_running;
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
                AppStrings.autoLogoutAndExit,
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

  Widget _buildRunButton(ThemeData theme) {
    final onCooldown = _cooldownRemaining > 0;
    final canRun = widget.loginDateTime != null &&
        widget.loginId != null &&
        !_running &&
        !onCooldown;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canRun ? _run : null,
        icon: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                onCooldown
                    ? Icons.timer_outlined
                    : (_isUnlock ? Icons.lock_open : Icons.card_giftcard),
                size: 20,
              ),
        label: Text(
          _running
              ? AppStrings.unlockRunning
              : onCooldown
                  ? AppStrings.ticketCooldownCountdown(_cooldownRemaining)
                  : _isUnlock
                      ? AppStrings.unlockMusicRun
                      : AppStrings.collectiblesRun,
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

  Widget _buildProgressCard(ThemeData theme) {
    final isFailed = _step == MusicRiskStep.failed;
    final isDone = _step == MusicRiskStep.complete;

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
            _stepRow(MusicRiskStep.fetchData, AppStrings.unlockStepFetch, theme),
            _stepRow(
              MusicRiskStep.upload,
              _isUnlock
                  ? AppStrings.unlockStepUpload
                  : AppStrings.collectiblesStepUpload,
              theme,
            ),
            if (_autoLogout)
              _stepRow(MusicRiskStep.logout, AppStrings.stepLogout, theme),
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

  Widget _stepRow(MusicRiskStep step, String label, ThemeData theme) {
    IconData icon;
    Color? color;

    if (_step == MusicRiskStep.failed && _step.index <= step.index) {
      icon = _step == step ? Icons.error : Icons.circle_outlined;
      color = _step == step
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant;
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

  Widget _buildDropdown({
    required int value,
    required String label,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      items: items,
      onChanged: _running
          ? null
          : (v) {
              if (v == null) return;
              onChanged(v);
            },
    );
  }
}

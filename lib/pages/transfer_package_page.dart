import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/upsert_user_all.dart';
import '../services/title_api_service.dart';
import 'transfer_advanced_page.dart';

enum TransferStep { idle, fetching, ready, sending, done, failed }

class TransferPackagePage extends StatefulWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? playlogId;
  final String? lastLoginDate;

  const TransferPackagePage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.playlogId,
    this.lastLoginDate,
  });

  @override
  State<TransferPackagePage> createState() => _TransferPackagePageState();
}

/// Lightweight data-only row — no controllers, no FocusNodes.
class _CharEntry {
  int characterId;
  int level;
  int awakening;
  int useCount;

  _CharEntry({
    required this.characterId,
    this.level = 1,
    this.awakening = 0,
    this.useCount = 0,
  });
}

class _TransferPackagePageState extends State<TransferPackagePage> {
  TransferStep _step = TransferStep.idle;
  String? _error;

  Map<String, Map<String, dynamic>>? _apiData;

  final List<TextEditingController> _slotCtrls =
      List.generate(5, (_) => TextEditingController());
  final List<TextEditingController> _lockSlotCtrls =
      List.generate(5, (_) => TextEditingController());

  /// Character data — plain list, no widgets attached.
  final List<_CharEntry> _charEntries = [];

  /// Search filter
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  /// Display cap — only show first N items initially.
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;

  /// Advanced raw-JSON fields editable via the advanced page.
  AdvancedFields _advanced = AdvancedFields();

  // ── Cooldown (same as TicketPage: 60s after login) ──
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void didUpdateWidget(covariant TransferPackagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _slotCtrls) {
      c.dispose();
    }
    for (final c in _lockSlotCtrls) {
      c.dispose();
    }
    _searchCtrl.dispose();
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

  // ─── Data fetching ───────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() {
      _step = TransferStep.fetching;
      _error = null;
      _apiData = null;
      _charEntries.clear();
      _searchQuery = '';
      _searchCtrl.clear();
      _visibleCount = _pageSize;
    });

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);

      final data = await service.fetchUserAllData(widget.userId);

      List<Map<String, dynamic>> charList;
      try {
        charList = await service.getUserCharacter(widget.userId);
      } catch (_) {
        charList = [];
      }

      if (!mounted) return;

      final userDataJson = data['GetUserDataApi']!;
      final ud =
          (userDataJson['userData'] as Map<String, dynamic>?) ?? const {};

      final slot = List<int>.from((ud['charaSlot'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt()) ??
          [0, 0, 0, 0, 0]);
      final lock = List<int>.from((ud['charaLockSlot'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt()) ??
          [0, 0, 0, 0, 0]);

      for (var i = 0; i < 5; i++) {
        _slotCtrls[i].text = slot.length > i ? '${slot[i]}' : '0';
        _lockSlotCtrls[i].text = lock.length > i ? '${lock[i]}' : '0';
      }

      for (final c in charList) {
        _charEntries.add(_CharEntry(
          characterId: (c['characterId'] as num?)?.toInt() ?? 0,
          level: (c['level'] as num?)?.toInt() ?? 1,
          awakening: (c['awakening'] as num?)?.toInt() ?? 0,
          useCount: (c['useCount'] as num?)?.toInt() ?? 0,
        ));
      }

      setState(() {
        _apiData = data;
        _step = TransferStep.ready;
      });
    } on TitleApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _step = TransferStep.failed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _step = TransferStep.failed;
      });
    }
  }

  // ─── Send ────────────────────────────────────────────────────────────────

  Future<void> _sendPackage() async {
    if (_apiData == null) return;
    if (!TitleServerConfigHolder().isConfigured) return;

    final loginDateTime = widget.loginDateTime;
    if (loginDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.transferNotLoggedIn)),
      );
      return;
    }

    setState(() {
      _step = TransferStep.sending;
      _error = null;
    });

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final payload = _buildPayload();
      await service.upsertUserAll(payload.toJson(), widget.userId);

      if (!mounted) return;
      setState(() => _step = TransferStep.done);
    } on TitleApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _step = TransferStep.failed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _step = TransferStep.failed;
      });
    }
  }

  UpsertUserAllPayload _buildPayload() {
    final data = _apiData!;
    final loginDt = widget.loginDateTime ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final userDataJson = data['GetUserDataApi']!;
    final userExtendJson = data['GetUserExtendApi']!;
    final userOptionJson = data['GetUserOptionApi']!;
    final userRatingJson = data['GetUserRatingApi']!;
    final userChargeJson = data['GetUserChargeApi']!;
    final userActivityJson = data['GetUserActivityApi']!;
    final userMissionJson = data['GetUserMissionDataApi']!;

    final charaSlot =
        _slotCtrls.map((c) => int.tryParse(c.text) ?? 0).toList();
    final charaLockSlot =
        _lockSlotCtrls.map((c) => int.tryParse(c.text) ?? 0).toList();

    final userCharacterList = _charEntries
        .where((e) => e.characterId > 0)
        .map((e) => UserCharacter(
              characterId: e.characterId,
              level: e.level,
              awakening: e.awakening,
              useCount: e.useCount,
            ))
        .toList();

    final ud =
        (userDataJson['userData'] as Map<String, dynamic>?) ?? const {};
    final ue =
        (userExtendJson['userExtend'] as Map<String, dynamic>?) ?? const {};
    final uo =
        (userOptionJson['userOption'] as Map<String, dynamic>?) ?? const {};
    final ur =
        (userRatingJson['userRating'] as Map<String, dynamic>?) ?? const {};
    final uc =
        (userChargeJson['userChargeList'] as List<dynamic>?) ?? const [];
    final ua =
        (userActivityJson['userActivity'] as Map<String, dynamic>?) ??
            const {};
    final um = (userMissionJson['userMissionDataList'] as List<dynamic>?) ??
        const [];
    final uw =
        (userMissionJson['userWeeklyData'] as Map<String, dynamic>?) ??
            const {};

    final cfg = TitleServerConfigHolder().config;
    final clientId = ud['lastClientId'] ?? cfg?.clientId ?? '';

    // Build musicData for userMusicDetailList — must NOT be empty.
    // Matches the playlog entry below (same musicId/level/achievement/…).
    final musicData = <String, dynamic>{
      'musicId': 834,
      'level': 4,
      'playCount': 1,
      'achievement': 1000000,
      'comboStatus': 3,
      'syncStatus': 0,
      'deluxscoreMax': 0,
      'scoreRank': 13,
      'extNum1': 0,
    };

    final upsertUserAll = {
      'userData': [
        {
          ...ud,
          'playCount': (ud['playCount'] as int? ?? 0) + 1,
          'currentPlayCount':
              (ud['currentPlayCount'] as int? ?? 0) + 1,
          'lastLoginDate':
              widget.lastLoginDate ?? ud['lastLoginDate'] ?? '',
          'banState': userDataJson['banState'] ?? ud['banState'] ?? 0,
          'charaSlot': charaSlot,
          'charaLockSlot': charaLockSlot,
          'lastGameId': 'SDGB',
          'lastRomVersion': ud['lastRomVersion'] ?? '1.53.00',
          'lastDataVersion': ud['lastDataVersion'] ?? '1.50.14',
          'lastPlayDate': _nowStr(),
          'lastPlayCredit': 1,
          'lastPlayMode': 0,
          'lastPlaceId': cfg?.placeId ?? ud['lastPlaceId'] ?? 0,
          'lastPlaceName':
              cfg?.placeName ?? ud['lastPlaceName'] ?? '',
          'lastRegionId': cfg?.regionId ?? ud['lastRegionId'] ?? 0,
          'lastRegionName':
              cfg?.regionName ?? ud['lastRegionName'] ?? '',
          'lastAllNetId': ud['lastAllNetId'] ?? 0,
          'lastCountryCode': ud['lastCountryCode'] ?? 'CHN',
          'lastClientId': clientId,
          'dateTime': loginDt,
        },
      ],
      'userExtend': [ue],
      'userOption': [uo],
      'userCharacterList':
          userCharacterList.map((c) => c.toJson()).toList(),
      'userGhost': <dynamic>[],
      'userMapList': _advanced.parsedUserMapList('[]'),
      'userLoginBonusList': _advanced.parsedUserLoginBonusList('[]'),
      'userRatingList': [ur],
      'userItemList': _advanced.parsedUserItemList('[]'),
      'userMusicDetailList': [musicData],
      'userCourseList': <dynamic>[],
      'userFriendSeasonRankingList': <dynamic>[],
      'userChargeList': uc,
      'userFavoriteList': <dynamic>[
        {'itemKind': 3, 'itemIdList': <dynamic>[]},
        {'itemKind': 1, 'itemIdList': <dynamic>[]},
        {'itemKind': 2, 'itemIdList': <dynamic>[]},
        {'itemKind': 10, 'itemIdList': <dynamic>[]},
        {'itemKind': 11, 'itemIdList': <dynamic>[]},
      ],
      'userActivityList': [ua],
      'userMissionDataList': um,
      'userWeeklyData': uw,
      'userGamePlaylogList': <dynamic>[
        {
          'playlogId': widget.playlogId ?? 0,
          'version': ud['lastRomVersion'] ?? '1.53.00',
          'playDate': _nowStr(),
          'playMode': 0,
          'useTicketId': -1,
          'playCredit': 1,
          'playTrack': 1,
          'clientId':
              ud['lastClientId'] ??
                  TitleServerConfigHolder().config?.clientId ??
                  '',
          'isPlayTutorial': false,
          'isEventMode': false,
          'isNewFree': false,
          'playCount': 0,
          'playSpecial': TitleApiService.calcRandom(),
          'playOtherUserId': 0,
        },
      ],
      'user2pPlaylog': {
        'userId1': 0,
        'userId2': 0,
        'userName1': '',
        'userName2': '',
        'regionId': 0,
        'placeId': 0,
        'user2pPlaylogDetailList': <dynamic>[],
      },
      'userIntimateList': <dynamic>[],
      'userShopItemStockList': <dynamic>[],
      'userGetPointList': _advanced.parsedUserGetPointList('[]'),
      'userTradeItemList': _advanced.parsedUserTradeItemList('[]'),
      'userFavoritemusicList': <dynamic>[],
      'userKaleidxScopeList': <dynamic>[],
      'isNewCharacterList': '',
      'isNewMapList': '',
      'isNewLoginBonusList': '',
      'isNewItemList': '',
      'isNewMusicDetailList': '0',
      'isNewCourseList': '',
      'isNewFavoriteList': '11111',
      'isNewFriendSeasonRankingList': '',
      'isNewUserIntimateList': '',
      'isNewFavoritemusicList': '',
      'isNewKaleidxScopeList': '',
    };

    // Minimal playlog entry — required, server rejects empty playlogList.
    final rating = ud['playerRating'] as int? ?? 0;
    final playlog = <String, dynamic>{
      'userId': 0, 'orderId': 0,
      'playlogId': widget.playlogId ?? 0, 'version': 1053000,
      'placeId': cfg?.placeId ?? 0,
      'placeName': cfg?.placeName ?? '',
      'loginDate': loginDt,
      'playDate': _nowStr().split(' ')[0],
      'userPlayDate': _nowStr(), 'type': 0,
      'musicId': 834, 'level': 4, 'trackNo': 1,
      'vsMode': 0, 'vsUserName': '', 'vsStatus': 0,
      'vsUserRating': 0, 'vsUserAchievement': 0, 'vsUserGradeRank': 0,
      'vsRank': 0, 'playerNum': 1,
      'playedUserId1': 0, 'playedUserName1': '', 'playedMusicLevel1': 0,
      'playedUserId2': 0, 'playedUserName2': '', 'playedMusicLevel2': 0,
      'playedUserId3': 0, 'playedUserName3': '', 'playedMusicLevel3': 0,
      'characterId1': charaSlot.isNotEmpty ? charaSlot[0] : 0,
      'characterLevel1': 1, 'characterAwakening1': 0,
      'characterId2': charaSlot.length > 1 ? charaSlot[1] : 0,
      'characterLevel2': 1, 'characterAwakening2': 0,
      'characterId3': charaSlot.length > 2 ? charaSlot[2] : 0,
      'characterLevel3': 1, 'characterAwakening3': 0,
      'characterId4': charaSlot.length > 3 ? charaSlot[3] : 0,
      'characterLevel4': 1, 'characterAwakening4': 0,
      'characterId5': charaSlot.length > 4 ? charaSlot[4] : 0,
      'characterLevel5': 1, 'characterAwakening5': 0,
      'achievement': 1000000, 'deluxscore': 0, 'scoreRank': 13,
      'maxCombo': 0, 'totalCombo': 128, 'maxSync': 0, 'totalSync': 0,
      'tapCriticalPerfect': 101, 'tapPerfect': 0, 'tapGreat': 0,
      'tapGood': 0, 'tapMiss': 0,
      'holdCriticalPerfect': 9, 'holdPerfect': 0, 'holdGreat': 0,
      'holdGood': 0, 'holdMiss': 0,
      'slideCriticalPerfect': 4, 'slidePerfect': 0, 'slideGreat': 0,
      'slideGood': 0, 'slideMiss': 0,
      'touchCriticalPerfect': 0, 'touchPerfect': 0, 'touchGreat': 0,
      'touchGood': 0, 'touchMiss': 0,
      'breakCriticalPerfect': 1, 'breakPerfect': 0, 'breakGreat': 0,
      'breakGood': 0, 'breakMiss': 0,
      'isTap': true, 'isHold': true, 'isSlide': true, 'isTouch': false,
      'isBreak': true, 'isCriticalDisp': true, 'isFastLateDisp': true,
      'fastCount': 0, 'lateCount': 0,
      'isAchieveNewRecord': false, 'isDeluxscoreNewRecord': false,
      'comboStatus': 3, 'syncStatus': 0, 'isClear': true,
      'beforeRating': rating, 'afterRating': rating,
      'beforeGrade': 0, 'afterGrade': 0, 'afterGradeRank': 0,
      'beforeDeluxRating': rating, 'afterDeluxRating': rating,
      'isPlayTutorial': false, 'isEventMode': false, 'isFreedomMode': false,
      'playMode': 0, 'isNewFree': false, 'trialPlayAchievement': -1,
      'extNum1': 0, 'extNum2': 0, 'extNum4': 101,
      'extBool1': false, 'extBool2': false,
    };

    return UpsertUserAllPayload(
      userId: widget.userId,
      playlogId: widget.playlogId ?? 0,
      loginDateTime: loginDt,
      upsertUserAll: upsertUserAll,
      charaSlot: charaSlot,
      charaLockSlot: charaLockSlot,
      userCharacterList: userCharacterList,
      userPlaylog: playlog,
    );
  }

  String _nowStr() {
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)} '
        '${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}.0';
  }

  // ─── Search / filter ─────────────────────────────────────────────────────

  List<_CharEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _charEntries;
    final q = _searchQuery.toLowerCase();
    return _charEntries
        .where((e) => e.characterId.toString().contains(q))
        .toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
      _visibleCount = _pageSize;
    });
  }

  // ─── Edit dialog ─────────────────────────────────────────────────────────

  Future<void> _openEditDialog(_CharEntry entry) async {
    final idCtrl = TextEditingController(text: '${entry.characterId}');
    final levelCtrl = TextEditingController(text: '${entry.level}');
    final awakeningCtrl =
        TextEditingController(text: '${entry.awakening}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑角色'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '角色 ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: levelCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '等级',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: awakeningCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '觉醒',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    idCtrl.dispose();
    levelCtrl.dispose();
    awakeningCtrl.dispose();

    if (ok == true) {
      setState(() {
        entry.characterId = int.tryParse(idCtrl.text) ?? entry.characterId;
        entry.level = int.tryParse(levelCtrl.text) ?? entry.level;
        entry.awakening =
            int.tryParse(awakeningCtrl.text) ?? entry.awakening;
      });
    }
  }

  // ─── Batch operations ────────────────────────────────────────────────────

  Future<void> _batchSetLevel() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量设置等级'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '目标等级',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('全部设置'),
          ),
        ],
      ),
    );
    final level = int.tryParse(ctrl.text);
    ctrl.dispose();

    if (ok == true && level != null) {
      setState(() {
        for (final e in _charEntries) {
          e.level = level;
        }
      });
    }
  }

  void _addCharacterRow() {
    setState(() {
      _charEntries.add(_CharEntry(characterId: 0, level: 1));
    });
  }

  void _removeCharacter(int index) {
    // Index in the filtered list — find the actual entry
    final filtered = _filteredEntries;
    if (index >= filtered.length) return;
    final entry = filtered[index];
    final realIdx = _charEntries.indexOf(entry);
    if (realIdx >= 0) {
      setState(() => _charEntries.removeAt(realIdx));
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

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
              Text(AppStrings.titleServerNotConfigured,
                  style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top section (description + fetch button) — always visible
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: responsiveMaxWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.loginDateTime == null)
                  _buildBanner(
                    theme,
                    Icons.warning_amber_rounded,
                    AppStrings.transferNotLoggedIn,
                    theme.colorScheme.errorContainer,
                    theme.colorScheme.onErrorContainer,
                  ),
                if (widget.loginDateTime != null && _cooldownRemaining > 0)
                  _buildCooldownBanner(theme),
                _buildDescCard(theme),
                const SizedBox(height: 12),
                _buildFetchButton(theme),
                const SizedBox(height: 4),
                _buildAdvancedButton(theme),
              ],
            ),
          ),
        ),

        // Data sections — scrollable
        if (_apiData != null && _step != TransferStep.fetching)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: responsiveMaxWidth(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSlotSection(theme),
                    const SizedBox(height: 12),
                    _buildCharacterSection(theme),
                    const SizedBox(height: 20),
                    _buildSendButton(theme),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorCard(theme),
                    ],
                    if (_step == TransferStep.done) ...[
                      const SizedBox(height: 12),
                      _buildDoneCard(theme),
                    ],
                  ],
                ),
              ),
            ),
          ),

        if (_step == TransferStep.fetching || _step == TransferStep.sending)
          _buildProgress(theme),
        if (_error != null && _apiData == null) ...[
          const SizedBox(height: 12),
          _buildErrorCard(theme),
        ],
      ],
    );
  }

  Widget _buildDescCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        AppStrings.transferDesc,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
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
              AppStrings.packetCooldownNotice(_cooldownRemaining),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openAdvancedPage,
        icon: const Icon(Icons.tune, size: 18),
        label: const Text('高级字段'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _openAdvancedPage() async {
    final result = await Navigator.of(context).push<AdvancedFields>(
      MaterialPageRoute(
        builder: (_) => TransferAdvancedPage(initial: _advanced),
      ),
    );
    if (result != null) {
      setState(() => _advanced = result);
    }
  }

  Widget _buildBanner(
    ThemeData theme,
    IconData icon,
    String text,
    Color bgColor,
    Color fgColor,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: fgColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchButton(ThemeData theme) {
    final hasLogin = widget.loginDateTime != null;
    final isLoading = _step == TransferStep.fetching;
    final isSending = _step == TransferStep.sending;
    final canFetch = hasLogin && !isLoading && !isSending;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canFetch ? _fetchData : null,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download, size: 20),
        label: Text(isLoading
            ? AppStrings.transferFetching
            : AppStrings.transferFetchData),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.transferCharaSlot,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${AppStrings.transferSlotLabel} $i',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _slotCtrls[i],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              AppStrings.transferCharaLockSlot,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${AppStrings.transferSlotLabel} $i',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _lockSlotCtrls[i],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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

  // ─── Character section (optimised) ───────────────────────────────────────

  Widget _buildCharacterSection(ThemeData theme) {
    final filtered = _filteredEntries;
    final visible = filtered.length > _visibleCount
        ? filtered.sublist(0, _visibleCount)
        : filtered;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with count
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppStrings.transferCharacterLevels} (${_charEntries.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _batchSetLevel,
                  icon: const Icon(Icons.dynamic_feed, size: 16),
                  label: Text('批量改等级',
                      style: theme.textTheme.labelSmall),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCharacterRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppStrings.transferAddCharacter,
                      style: theme.textTheme.labelSmall),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search box
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索角色ID...',
                prefixIcon:
                    const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // List — uses a fixed-height container + ListView.builder
            // so only visible rows are built.
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _searchQuery.isNotEmpty
                      ? '没有匹配的角色。'
                      : '暂无角色。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              // Table header
              _charTableHeader(theme),
              SizedBox(
                // Cap height at ~10 rows to keep scrolling performant
                height: (visible.length.clamp(0, 10) * 40.0 + 4)
                    .toDouble(),
                child: ListView.builder(
                  itemCount: visible.length,
                  itemExtent: 40,
                  itemBuilder: (ctx, i) =>
                      _charRow(theme, visible[i], i),
                ),
              ),
              // "show more" button
              if (_visibleCount < filtered.length)
                TextButton(
                  onPressed: () => setState(() =>
                      _visibleCount += _pageSize),
                  child: Text(
                    '显示更多 (已显示 $_visibleCount / ${filtered.length})',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _charTableHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            flex: 3,
            child: Text('ID',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 2,
            child: Text('等级',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 2,
            child: Text('觉醒',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _charRow(ThemeData theme, _CharEntry entry, int displayIdx) {
    return InkWell(
      onTap: () => _openEditDialog(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Icon(Icons.edit, size: 14,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5)),
            ),
            Expanded(
              flex: 3,
              child: Text('${entry.characterId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace')),
            ),
            Expanded(
              flex: 2,
              child: Text('${entry.level}',
                  style: theme.textTheme.bodySmall),
            ),
            Expanded(
              flex: 2,
              child: Text('${entry.awakening}',
                  style: theme.textTheme.bodySmall),
            ),
            IconButton(
              icon: Icon(Icons.remove_circle_outline, size: 16,
                  color: theme.colorScheme.error),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: AppStrings.transferRemove,
              onPressed: () => _removeCharacter(displayIdx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    final isSending = _step == TransferStep.sending;
    final hasLogin = widget.loginDateTime != null;
    final onCooldown = _cooldownRemaining > 0;
    final canSend = hasLogin && !isSending && !onCooldown;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canSend ? _sendPackage : null,
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.file_upload_outlined, size: 20),
        label: Text(isSending
            ? AppStrings.transferSending
            : AppStrings.transferSend),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              _step == TransferStep.fetching
                  ? AppStrings.transferFetching
                  : AppStrings.transferSending,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, size: 16,
                  color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Text(
                AppStrings.transferFailed,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            AppStrings.transferSuccess,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/upsert_user_all.dart';
import '../services/title_api_service.dart';

enum TransferStep { idle, fetching, ready, sending, done, failed }

/// Third-party score upload page (传送分数).
///
/// Fetches the user's current server state, then uploads a single song score
/// as one valid play session via UpsertUserAllApi. Aligned with the reference
/// Python implementation (UpsertMusic.py / payload.py) and the 1.55.01 dump.
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

class _TransferPackagePageState extends State<TransferPackagePage> {
  TransferStep _step = TransferStep.idle;
  String? _error;

  Map<String, Map<String, dynamic>>? _apiData;

  // ── Score form state ──
  final _musicIdCtrl = TextEditingController();
  final _achievementCtrl = TextEditingController(text: '1010000');
  final _deluxCtrl = TextEditingController(text: '0');
  final _playCountCtrl = TextEditingController(text: '1');
  int _level = 3; // Master by default
  int _comboStatus = 0;
  int _syncStatus = 0;

  // ── Cooldown (same as TicketPage: 60s after login) ──
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
    _achievementCtrl.addListener(_onAchievementChanged);
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
    _achievementCtrl.removeListener(_onAchievementChanged);
    _musicIdCtrl.dispose();
    _achievementCtrl.dispose();
    _deluxCtrl.dispose();
    _playCountCtrl.dispose();
    super.dispose();
  }

  void _onAchievementChanged() => setState(() {});

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
    });

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);

      final data = await service.fetchUserAllData(widget.userId);

      if (!mounted) return;
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

  // ─── Score helpers ─────────────────────────────────────────────────────

  /// Parse a rom version string like "1.55.01" into the int form 1055001
  /// (major*1000000 + minor*1000 + patch). Falls back to 1055001.
  static int _romVersionToInt(String version) {
    final parts = version.split('.');
    if (parts.length < 3) return 1055001;
    final major = int.tryParse(parts[0]) ?? 1;
    final minor = int.tryParse(parts[1]) ?? 55;
    final patch = int.tryParse(parts[2]) ?? 1;
    return major * 1000000 + minor * 1000 + patch;
  }

  /// Derive scoreRank enum from achievement (verified against the dump:
  /// 996696→11, 1004084→12, 1006702→13).
  static int _scoreRankFromAchievement(int a) {
    if (a >= 1005000) return 13; // SSS+
    if (a >= 1000000) return 12; // SSS
    if (a >= 995000) return 11; // SS+
    if (a >= 990000) return 10; // SS
    if (a >= 980000) return 9; // S+
    if (a >= 970000) return 8; // S
    if (a >= 940000) return 7; // AAA
    if (a >= 900000) return 6; // AA
    if (a >= 800000) return 5; // A
    if (a >= 750000) return 4; // BBB
    if (a >= 700000) return 3; // BB
    if (a >= 600000) return 2; // B
    if (a >= 500000) return 1; // C
    return 0; // D
  }

  /// Live preview of the rank label for the current achievement input.
  String _currentRankLabel() {
    final a = int.tryParse(_achievementCtrl.text) ?? 0;
    final rank = _scoreRankFromAchievement(a);
    const names = {
      13: 'SSS+', 12: 'SSS', 11: 'SS+', 10: 'SS', 9: 'S+', 8: 'S',
      7: 'AAA', 6: 'AA', 5: 'A', 4: 'BBB', 3: 'BB', 2: 'B', 1: 'C', 0: 'D',
    };
    final pct = (a / 10000).toStringAsFixed(4);
    return '$pct%  ·  ${names[rank]} ($rank)';
  }

  Map<String, dynamic> get _userDataMap {
    final data = _apiData;
    if (data == null) return const {};
    final json = data['GetUserDataApi'];
    return (json?['userData'] as Map<String, dynamic>?) ?? const {};
  }

  int get _apiRating => (_userDataMap['playerRating'] as num?)?.toInt() ?? 0;

  String _nowStr() {
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)} '
        '${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}.0';
  }

  List<int> _charaSlot() {
    final raw = _userDataMap['charaSlot'] as List<dynamic>?;
    final slot = raw?.map((e) => (e as num).toInt()).toList() ?? const [];
    return List<int>.generate(5, (i) => i < slot.length ? slot[i] : 0);
  }

  // ─── Send ──────────────────────────────────────────────────────────────

  Future<void> _sendScore() async {
    if (_apiData == null) return;
    if (!TitleServerConfigHolder().isConfigured) return;

    final loginDateTime = widget.loginDateTime;
    if (loginDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.transferNotLoggedIn)),
      );
      return;
    }

    final musicId = int.tryParse(_musicIdCtrl.text);
    final achievement = int.tryParse(_achievementCtrl.text);
    if (musicId == null || musicId <= 0 || achievement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.scoreInvalidInput)),
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

      final payload = _buildScorePayload(
        musicId: musicId,
        achievement: achievement,
        loginDateTime: loginDateTime,
      );
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

  // ─── Build UpsertUserAll payload ────────────────────────────────────────

  UpsertUserAllPayload _buildScorePayload({
    required int musicId,
    required int achievement,
    required int loginDateTime,
  }) {
    final data = _apiData!;
    final ud = _userDataMap;
    final ue =
        (data['GetUserExtendApi']?['userExtend'] as Map<String, dynamic>?) ??
            const {};
    final uo =
        (data['GetUserOptionApi']?['userOption'] as Map<String, dynamic>?) ??
            const {};
    final ur =
        (data['GetUserRatingApi']?['userRating'] as Map<String, dynamic>?) ??
            const {};
    final uc =
        (data['GetUserChargeApi']?['userChargeList'] as List<dynamic>?) ??
            const [];
    final ua =
        (data['GetUserActivityApi']?['userActivity'] as Map<String, dynamic>?) ??
            const {};
    final um =
        (data['GetUserMissionDataApi']?['userMissionDataList']
            as List<dynamic>?) ??
            const [];
    final uw =
        (data['GetUserMissionDataApi']?['userWeeklyData']
            as Map<String, dynamic>?) ??
            const {};

    final cfg = TitleServerConfigHolder().config;
    final romVerStr = (ud['lastRomVersion'] as String?) ?? '1.55.01';
    final clientId = (ud['lastClientId'] as String?) ?? cfg?.clientId ?? '';
    final playlogId = widget.playlogId ?? 0;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final playCount = (ud['playCount'] as num?)?.toInt() ?? 0;
    final currentPlayCount =
        (ud['currentPlayCount'] as num?)?.toInt() ?? 0;

    final deluxscore = int.tryParse(_deluxCtrl.text) ?? 0;
    final musicPlayCount = int.tryParse(_playCountCtrl.text) ?? 1;
    final scoreRank = _scoreRankFromAchievement(achievement);

    final musicDetail = _makeMusicDetail(
      musicId: musicId,
      achievement: achievement,
      deluxscoreMax: deluxscore,
      scoreRank: scoreRank,
      playCount: musicPlayCount,
    );

    final playlog = _makePlaylogEntry(
      playlogId: playlogId,
      romVerInt: _romVersionToInt(romVerStr),
      musicId: musicId,
      achievement: achievement,
      deluxscore: deluxscore,
      scoreRank: scoreRank,
      loginDateTime: loginDateTime,
    );

    final upsertUserAll = {
      'userData': [
        {
          ...ud,
          'accessCode': '',
          'lastGameId': 'SDGB',
          'lastRomVersion': romVerStr,
          'lastDataVersion': ud['lastDataVersion'] ?? romVerStr,
          'lastLoginDate': widget.lastLoginDate ?? ud['lastLoginDate'] ?? '',
          'lastPlayDate': _nowStr(),
          'lastPlayCredit': 1,
          'lastPlayMode': 0,
          'lastPlaceId': cfg?.placeId ?? ud['lastPlaceId'] ?? 0,
          'lastPlaceName': cfg?.placeName ?? ud['lastPlaceName'] ?? '',
          'lastAllNetId': ud['lastAllNetId'] ?? 0,
          'lastRegionId': cfg?.regionId ?? ud['lastRegionId'] ?? 0,
          'lastRegionName': cfg?.regionName ?? ud['lastRegionName'] ?? '',
          'lastClientId': clientId,
          'lastCountryCode': ud['lastCountryCode'] ?? 'CHN',
          'playCount': playCount + 1,
          'currentPlayCount': currentPlayCount + 1,
          'banState': data['GetUserDataApi']?['banState'] ?? ud['banState'] ?? 0,
          'dateTime': nowSec,
        },
      ],
      'userExtend': [ue],
      'userOption': [uo],
      'userCharacterList': <dynamic>[],
      'userGhost': <dynamic>[],
      'userMapList': <dynamic>[],
      'userLoginBonusList': <dynamic>[],
      'userRatingList': [ur],
      'userItemList': <dynamic>[],
      'userMusicDetailList': [musicDetail],
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
          'playlogId': playlogId,
          'version': romVerStr,
          'playDate': _nowStr(),
          'playMode': 0,
          'useTicketId': -1,
          'playCredit': 1,
          'playTrack': 1,
          'clientId': clientId,
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
      'userGetPointList': <dynamic>[],
      'userTradeItemList': <dynamic>[],
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

    return UpsertUserAllPayload(
      userId: widget.userId,
      playlogId: playlogId,
      loginDateTime: loginDateTime,
      upsertUserAll: upsertUserAll,
      userPlaylog: playlog,
    );
  }

  Map<String, dynamic> _makeMusicDetail({
    required int musicId,
    required int achievement,
    required int deluxscoreMax,
    required int scoreRank,
    required int playCount,
  }) {
    return {
      'musicId': musicId,
      'level': _level,
      'playCount': playCount,
      'achievement': achievement,
      'comboStatus': _comboStatus,
      'syncStatus': _syncStatus,
      'deluxscoreMax': deluxscoreMax,
      'scoreRank': scoreRank,
      'extNum1': 0,
    };
  }

  /// Build the userPlaylogList entry. Judgment detail uses the placeholder
  /// values from the reference Python script (payload.py). Character levels
  /// are 1/0 since this page no longer edits characters.
  Map<String, dynamic> _makePlaylogEntry({
    required int playlogId,
    required int romVerInt,
    required int musicId,
    required int achievement,
    required int deluxscore,
    required int scoreRank,
    required int loginDateTime,
  }) {
    final rating = _apiRating;
    final cfg = TitleServerConfigHolder().config;
    final slot = _charaSlot();

    return {
      'userId': 0,
      'orderId': 0,
      'playlogId': playlogId,
      'version': romVerInt,
      'placeId': cfg?.placeId ?? 0,
      'placeName': cfg?.placeName ?? '',
      'loginDate': loginDateTime,
      'playDate': _nowStr().split(' ')[0],
      'userPlayDate': _nowStr(),
      'type': 0,
      'musicId': musicId,
      'level': _level,
      'trackNo': 1,
      'vsMode': 0,
      'vsUserName': '',
      'vsStatus': 0,
      'vsUserRating': 0,
      'vsUserAchievement': 0,
      'vsUserGradeRank': 0,
      'vsRank': 0,
      'playerNum': 1,
      'playedUserId1': 0,
      'playedUserName1': '',
      'playedMusicLevel1': 0,
      'playedUserId2': 0,
      'playedUserName2': '',
      'playedMusicLevel2': 0,
      'playedUserId3': 0,
      'playedUserName3': '',
      'playedMusicLevel3': 0,
      'characterId1': slot[0],
      'characterLevel1': 1,
      'characterAwakening1': 0,
      'characterId2': slot[1],
      'characterLevel2': 1,
      'characterAwakening2': 0,
      'characterId3': slot[2],
      'characterLevel3': 1,
      'characterAwakening3': 0,
      'characterId4': slot[3],
      'characterLevel4': 1,
      'characterAwakening4': 0,
      'characterId5': slot[4],
      'characterLevel5': 1,
      'characterAwakening5': 0,
      'achievement': achievement,
      'deluxscore': deluxscore,
      'scoreRank': scoreRank,
      'maxCombo': 0,
      'totalCombo': 128,
      'maxSync': 0,
      'totalSync': 0,
      'tapCriticalPerfect': 101,
      'tapPerfect': 0,
      'tapGreat': 0,
      'tapGood': 0,
      'tapMiss': 0,
      'holdCriticalPerfect': 9,
      'holdPerfect': 0,
      'holdGreat': 0,
      'holdGood': 0,
      'holdMiss': 0,
      'slideCriticalPerfect': 4,
      'slidePerfect': 0,
      'slideGreat': 0,
      'slideGood': 0,
      'slideMiss': 0,
      'touchCriticalPerfect': 0,
      'touchPerfect': 0,
      'touchGreat': 0,
      'touchGood': 0,
      'touchMiss': 0,
      'breakCriticalPerfect': 1,
      'breakPerfect': 0,
      'breakGreat': 0,
      'breakGood': 0,
      'breakMiss': 0,
      'isTap': true,
      'isHold': true,
      'isSlide': true,
      'isTouch': false,
      'isBreak': true,
      'isCriticalDisp': true,
      'isFastLateDisp': true,
      'fastCount': 0,
      'lateCount': 0,
      'isAchieveNewRecord': false,
      'isDeluxscoreNewRecord': false,
      'comboStatus': _comboStatus,
      'syncStatus': _syncStatus,
      'isClear': true,
      'beforeRating': rating,
      'afterRating': rating,
      'beforeGrade': 0,
      'afterGrade': 0,
      'afterGradeRank': 0,
      'beforeDeluxRating': rating,
      'afterDeluxRating': rating,
      'isPlayTutorial': false,
      'isEventMode': false,
      'isFreedomMode': false,
      'playMode': 0,
      'isNewFree': false,
      'trialPlayAchievement': -1,
      'extNum1': 0,
      'extNum2': 0,
      'extNum4': 101,
      'extBool1': false,
      'extBool2': false,
    };
  }

  // ─── UI ─────────────────────────────────────────────────────────────────

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsiveMaxWidth(context)),
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
              ],
            ),
          ),
        ),
        if (_apiData != null && _step != TransferStep.fetching)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: responsiveMaxWidth(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataReadyBanner(theme),
                    const SizedBox(height: 12),
                    _buildScoreForm(theme),
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
        if (_step == TransferStep.fetching) _buildProgress(theme),
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

  Widget _buildDataReadyBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.transferDataReady,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
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
    final hasData = _apiData != null;

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
            : Icon(hasData ? Icons.refresh : Icons.download, size: 20),
        label: Text(isLoading
            ? AppStrings.transferFetching
            : (hasData
                ? AppStrings.transferRefetch
                : AppStrings.transferFetchData)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreForm(ThemeData theme) {
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
              AppStrings.scoreFormTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _numberField(
              theme,
              controller: _musicIdCtrl,
              label: AppStrings.scoreMusicId,
            ),
            const SizedBox(height: 14),
            _dropdownField(
              theme,
              label: AppStrings.scoreLevel,
              value: _level,
              labels: AppStrings.levelLabels,
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 14),
            _numberField(
              theme,
              controller: _achievementCtrl,
              label: AppStrings.scoreAchievement,
              helperText: AppStrings.scoreAchievementHint,
            ),
            const SizedBox(height: 6),
            _rankPreview(theme),
            const SizedBox(height: 14),
            _dropdownField(
              theme,
              label: AppStrings.scoreComboStatus,
              value: _comboStatus,
              labels: AppStrings.comboStatusLabels,
              onChanged: (v) => setState(() => _comboStatus = v),
            ),
            const SizedBox(height: 14),
            _dropdownField(
              theme,
              label: AppStrings.scoreSyncStatus,
              value: _syncStatus,
              labels: AppStrings.syncStatusLabels,
              onChanged: (v) => setState(() => _syncStatus = v),
            ),
            const SizedBox(height: 14),
            _numberField(
              theme,
              controller: _deluxCtrl,
              label: AppStrings.scoreDeluxscore,
            ),
            const SizedBox(height: 14),
            _numberField(
              theme,
              controller: _playCountCtrl,
              label: AppStrings.scorePlayCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _dropdownField(
    ThemeData theme, {
    required String label,
    required int value,
    required List<String> labels,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        for (var i = 0; i < labels.length; i++)
          DropdownMenuItem(value: i, child: Text(labels[i])),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _rankPreview(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.military_tech_outlined,
            size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          '${AppStrings.scoreRankLabel}: ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          _currentRankLabel(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
        onPressed: canSend ? _sendScore : null,
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
    final text = _step == TransferStep.fetching
        ? AppStrings.transferFetching
        : AppStrings.transferSending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              text,
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
              Icon(Icons.error,
                  size: 16, color: theme.colorScheme.onErrorContainer),
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

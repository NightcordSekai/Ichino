import '../config/title_server_config.dart';
import 'title_api_service.dart';

/// Dart port of `eaquira/src/sdgb/payload.py::UserAll_payload` and
/// `eaquira/action/UnlockMusic.py::music_user_all_patcher`.
///
/// Builds the UpsertUserAllApi request packet used by the
/// UpsertMusic (上传成绩) / UnlockMusic (解锁歌曲) workflows.
class UserAllPayloadBuilder {
  final TitleServerConfig config;

  const UserAllPayloadBuilder(this.config);

  static DateTime _shanghaiNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _formatPlayDate(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  static String _formatPlayDateTime(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}.0';

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// "1.56.00" -> 1056000 (Lionheart convertVersionNumber).
  static int _convertVersionNumber(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return 1053000;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return 1053000;
    return major * 1000000 + minor * 1000 + patch;
  }

  /// Build the UpsertUserAllApi packet.
  ///
  /// [generalUserInfo] is the result of `TitleApiService.fetchUserAllData`,
  /// keyed by the raw API names.
  Map<String, dynamic> build({
    required int userId,
    required int loginId,
    required int loginDateTime,
    required Map<String, dynamic> musicData,
    required Map<String, Map<String, dynamic>> generalUserInfo,
  }) {
    final userDataResp = generalUserInfo['GetUserDataApi'] ?? const {};
    final userExtendResp = generalUserInfo['GetUserExtendApi'] ?? const {};
    final userOptionResp = generalUserInfo['GetUserOptionApi'] ?? const {};
    final userRatingResp = generalUserInfo['GetUserRatingApi'] ?? const {};
    final userChargeResp = generalUserInfo['GetUserChargeApi'] ?? const {};
    final userActivityResp = generalUserInfo['GetUserActivityApi'] ?? const {};
    final userMissionResp = generalUserInfo['GetUserMissionDataApi'] ?? const {};

    final userData =
        userDataResp['userData'] as Map<String, dynamic>? ?? const {};
    final playerRating = _toInt(userData['playerRating']);

    final charaSlot = (userData['charaSlot'] as List<dynamic>? ?? const [])
        .map((e) => _toInt(e))
        .toList();
    final paddedCharaSlot = List<int>.generate(
      5,
      (i) => i < charaSlot.length ? charaSlot[i] : 0,
    );

    final now = _shanghaiNow();
    final playDate = _formatPlayDate(now);
    final playDateTime = _formatPlayDateTime(now);
    final loginDate =
        _formatPlayDateTime(DateTime.fromMillisecondsSinceEpoch(loginDateTime * 1000).toUtc().add(const Duration(hours: 8)));

    // Lionheart: GetUserDataApi 返回的部分字段不能出现在 UpsertUserAll 的
    // userData 中，否则服务器会静默丢弃整包处理。
    final newUserData = Map<String, dynamic>.from(userData)
      ..remove('friendCode')
      ..remove('nameplateId')
      ..remove('trophyId')
      ..remove('cmLastEmoneyBrand')
      ..remove('cmLastEmoneyCredit');
    newUserData
      ..['accessCode'] = ''
      ..['isNetMember'] = 1
      ..['playCount'] = _toInt(userData['playCount']) + 1
      ..['currentPlayCount'] = _toInt(userData['currentPlayCount']) + 1
      ..['lastGameId'] = 'SDGB'
      ..['lastLoginDate'] = loginDate
      ..['lastPlayDate'] = playDateTime
      ..['lastPlayCredit'] = 1
      ..['lastPlayMode'] = 0
      ..['lastPlaceId'] = config.placeId
      ..['lastPlaceName'] = config.placeName
      ..['lastAllNetId'] = 0
      ..['lastRegionId'] = config.regionId
      ..['lastRegionName'] = config.regionName
      ..['lastClientId'] = config.clientId
      ..['lastCountryCode'] = 'CHN'
      ..['banState'] = userDataResp['banState']
      ..['dateTime'] = loginDateTime;

    // Lionheart: userOption 需去掉 tempoVolume。
    final userOption =
        userOptionResp['userOption'] as Map<String, dynamic>? ?? const {};
    final newUserOption = Map<String, dynamic>.from(userOption)
      ..remove('tempoVolume');

    // Lionheart: userRating.udemae 的大写重复字段需去掉。
    final userRating =
        userRatingResp['userRating'] as Map<String, dynamic>? ?? const {};
    final udemae = userRating['udemae'] as Map<String, dynamic>?;
    if (udemae != null) {
      for (final key in [
        'MaxLoseNum',
        'NpcLoseNum',
        'NpcMaxLoseNum',
        'NpcMaxWinNum',
        'NpcTotalLoseNum',
        'NpcTotalWinNum',
        'NpcWinNum',
      ]) {
        udemae.remove(key);
      }
    }

    // Lionheart: userChargeList 只保留 4 个字段 (无 extNum1)。
    final userChargeList = [
      for (final c in (userChargeResp['userChargeList'] as List<dynamic>? ??
          const []))
        if (c is Map<String, dynamic>)
          {
            'chargeId': c['chargeId'],
            'stock': c['stock'],
            'purchaseDate': c['purchaseDate'],
            'validDate': c['validDate'],
          },
    ];

    final missionList =
        userMissionResp['userMissionDataList'] as List<dynamic>? ?? const [];
    final missions = <Map<String, dynamic>>[];
    for (final raw in missionList.take(6)) {
      final m = raw as Map<String, dynamic>;
      missions.add({
        'type': m['type'],
        'difficulty': m['difficulty'],
        'targetGenreId': m['targetGenreId'],
        'targetGenreTableId': m['targetGenreTableId'],
        'conditionGenreId': m['conditionGenreId'],
        'conditionGenreTableId': m['conditionGenreTableId'],
        'clearFlag': m['clearFlag'],
      });
    }

    final weekly =
        userMissionResp['userWeeklyData'] as Map<String, dynamic>? ?? const {};

    final achievement = _toInt(musicData['achievement']);
    final gradeRating = _toInt(userData['gradeRating']);
    final playlog = <String, dynamic>{
      'userId': 0,
      'orderId': 0,
      'playlogId': loginId,
      'version': _convertVersionNumber(
        userData['lastRomVersion'] as String? ?? '',
      ),
      'placeId': config.placeId,
      'placeName': config.placeName,
      'loginDate': loginDateTime,
      'playDate': playDate,
      'userPlayDate': playDateTime,
      'type': 0,
      'musicId': musicData['musicId'],
      'level': musicData['level'],
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
      'achievement': achievement,
      'deluxscore': musicData['deluxscoreMax'],
      'scoreRank': musicData['scoreRank'],
      'maxCombo': 0,
      'totalCombo': 1,
      'maxSync': 1,
      'totalSync': 0,
      'tapCriticalPerfect': 0,
      'tapPerfect': 0,
      'tapGreat': 0,
      'tapGood': 0,
      'tapMiss': 1,
      'holdCriticalPerfect': 0,
      'holdPerfect': 0,
      'holdGreat': 0,
      'holdGood': 0,
      'holdMiss': 0,
      'slideCriticalPerfect': 0,
      'slidePerfect': 0,
      'slideGreat': 0,
      'slideGood': 0,
      'slideMiss': 0,
      'touchCriticalPerfect': 0,
      'touchPerfect': 0,
      'touchGreat': 0,
      'touchGood': 0,
      'touchMiss': 0,
      'breakCriticalPerfect': 0,
      'breakPerfect': 0,
      'breakGreat': 0,
      'breakGood': 0,
      'breakMiss': 0,
      'isTap': true,
      'isHold': false,
      'isSlide': false,
      'isTouch': false,
      'isBreak': false,
      'isCriticalDisp': false,
      'isFastLateDisp': true,
      'fastCount': 0,
      'lateCount': 0,
      'isAchieveNewRecord': false,
      'isDeluxscoreNewRecord': false,
      'comboStatus': musicData['comboStatus'],
      'syncStatus': musicData['syncStatus'],
      'isClear': achievement >= 500000,
      'beforeRating': playerRating,
      'afterRating': playerRating,
      'beforeGrade': gradeRating,
      'afterGrade': gradeRating,
      'afterGradeRank': _toInt(userData['gradeRank']),
      'beforeDeluxRating': playerRating,
      'afterDeluxRating': playerRating,
      'isPlayTutorial': false,
      'isEventMode': false,
      'isFreedomMode': false,
      'playMode': 0,
      'isNewFree': false,
      'trialPlayAchievement': -1,
      'extNum1': 0,
      'extNum2': 0,
      'extNum4': 0,
      'extBool1': false,
      'extBool2': false,
    };
    for (var i = 0; i < 5; i++) {
      playlog['characterId${i + 1}'] = paddedCharaSlot[i];
      playlog['characterLevel${i + 1}'] = 1;
      playlog['characterAwakening${i + 1}'] = 0;
    }

    return {
      'userId': userId,
      'playlogId': loginId,
      'isEventMode': false,
      'isFreePlay': false,
      'loginDateTime': loginDateTime,
      'userPlaylogList': [playlog],
      'upsertUserAll': {
        'userData': [newUserData],
        'userExtend': [userExtendResp['userExtend']],
        'userOption': [newUserOption],
        'userCharacterList': [],
        'userGhost': [],
        'userMapList': [],
        'userLoginBonusList': [],
        'userRatingList': [userRating],
        'userItemList': [],
        'userMusicDetailList': [musicData],
        'userCourseList': [],
        'userFriendSeasonRankingList': [],
        'userChargeList': userChargeList,
        'userFavoriteList': [],
        'userActivityList': [userActivityResp['userActivity']],
        'userMissionDataList': missions,
        'userWeeklyData': {
          'lastLoginWeek': weekly['lastLoginWeek'],
          'beforeLoginWeek': weekly['beforeLoginWeek'],
          'friendBonusFlag': weekly['friendBonusFlag'],
        },
        'userGamePlaylogList': [
          {
            'playlogId': loginId,
            'version': userData['lastRomVersion'],
            'playDate': playDateTime,
            'playMode': 0,
            'useTicketId': -1,
            'playCredit': 1,
            'playTrack': 1,
            'clientId': config.clientId,
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
          'user2pPlaylogDetailList': [],
        },
        'userIntimateList': [],
        'userShopItemStockList': [],
        'userGetPointList': [],
        'userTradeItemList': [],
        'userFavoritemusicList': [],
        'userKaleidxScopeList': [],
        'isNewCharacterList': '',
        'isNewMapList': '',
        'isNewLoginBonusList': '',
        'isNewItemList': '',
        'isNewMusicDetailList': '0',
        'isNewCourseList': '',
        'isNewFavoriteList': '',
        'isNewFriendSeasonRankingList': '',
        'isNewUserIntimateList': '',
        'isNewFavoritemusicList': '',
        'isNewKaleidxScopeList': '',
      },
    };
  }

  /// Generic item patch: replace `userItemList` / `isNewItemList` in the packet.
  /// Used by UnlockMusic (itemKind 5/6/7) and 收藏品获取 (itemKind 1/2/3/10/11/12).
  void applyItemListPatch(
    Map<String, dynamic> packet, {
    required List<Map<String, dynamic>> items,
  }) {
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userItemList'] = items;
    upsert['isNewItemList'] = List.filled(items.length, '1').join();
  }

  /// Port of `music_user_all_patcher`: append unlock items
  /// (itemKind 5=music, 6=master, 7=remaster) to the packet.
  void applyMusicUnlockPatch(
    Map<String, dynamic> packet, {
    required Map<String, dynamic> musicData,
    required int musicId,
    bool unlockMusic = false,
    bool unlockMaster = false,
    bool unlockRemaster = false,
  }) {
    applyItemListPatch(packet, items: [
      if (unlockMusic)
        {'itemKind': 5, 'itemId': musicId, 'stock': 1, 'isValid': true},
      if (unlockMaster)
        {'itemKind': 6, 'itemId': musicId, 'stock': 1, 'isValid': true},
      if (unlockRemaster)
        {'itemKind': 7, 'itemId': musicId, 'stock': 1, 'isValid': true},
    ]);

    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userMusicDetailList'] = [musicData];
    upsert['isNewMusicDetailList'] = '1';
  }
}

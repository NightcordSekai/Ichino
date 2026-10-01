import '../config/title_server_config.dart';
import '../models/user_character.dart';
import 'title_api_service.dart';

/// Dart port of `eaquira/src/sdgb/payload.py::UserAll_payload` and
/// `eaquira/action/UnlockMusic.py::music_user_all_patcher`.
///
/// Builds the UpsertUserAllApi request packet used by the
/// UpsertMusic (上传成绩) / UnlockMusic (解锁歌曲) workflows.
class UserAllPayloadBuilder {
  /// `UserDetail` 里这些数值字段在 C# 侧都是 `int`，超出 int32 会让服务器
  /// 反序列化失败并回 500（同 `playSpecial` 那次）。舞里程直接用整个 int32 区间，
  /// 允许负值意味着「累加模式填负数就是扣里程」。
  static const int minValue = -2147483648;
  static const int maxValue = 2147483647;

  /// 总 Rating 的显示区间，游戏内没有超过 5 位的段位。
  static const int maxRating = 99999;

  /// `UserChara` 的真实等级上限（`RealLevelMax`）。界面上显示的等级是
  /// `level % 10000`、转生次数是 `level ~/ 10000`，所以 999999 = 99 转生 + 9999 级。
  static const int minCharacterLevel = 1;
  static const int maxCharacterLevel = 999999;

  /// 高危操作不写真实成绩，playlog 统一沿用这一条占位记录
  /// （eaquira `settings.musicData` 的默认曲 Amber Chronicle）。
  static const int placeholderMusicId = 11538;

  /// 占位 `musicData`。解锁歌曲时用待解锁曲目覆盖 [musicId]，其余字段照旧。
  static Map<String, dynamic> placeholderMusicData({int? musicId}) => {
        'musicId': musicId ?? placeholderMusicId,
        'level': 0,
        'playCount': 1,
        'achievement': 0,
        'comboStatus': 0,
        'syncStatus': 0,
        'deluxscoreMax': 0,
        'scoreRank': 0,
        'extNum1': 0,
      };

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

  /// 客户端 `TimeManager.GetDateString` 的格式是
  /// `ToString("yyyy-MM-dd HH:mm:ss.f")`，也就是带一位小数的秒。
  /// 万花筒的 `clearDate` 之类字段要按这个形状给。
  static String nowTimestamp() => _formatPlayDateTime(_shanghaiNow());

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static int clampValue(int v) =>
      v < minValue ? minValue : (v > maxValue ? maxValue : v);

  /// 旅行伙伴等级不允许 0，`UserChara.Clear()` 的初值就是 1。
  static int clampCharacterLevel(int v) =>
      v < minCharacterLevel
          ? minCharacterLevel
          : (v > maxCharacterLevel ? maxCharacterLevel : v);

  static Map<String, dynamic> _userDataOf(Map<String, dynamic> packet) =>
      ((packet['upsertUserAll'] as Map<String, dynamic>)['userData'] as List)
              .first
          as Map<String, dynamic>;

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
      'extBool3': false,
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
  ///
  /// [newFlags] 每一位对应一行：'1' 服务器没有这行（插入）、'0' 已有（更新）。
  /// 省略时全按 '1' 发。真机 `BuildListData` 是按 (itemKind, itemId) 主键比对
  /// 服务器快照算出这一位的，所以重复解锁同一首歌时必须发 '0'，否则服务器
  /// 可能当成插入冲突直接丢掉这一行。
  void applyItemListPatch(
    Map<String, dynamic> packet, {
    required List<Map<String, dynamic>> items,
    String? newFlags,
  }) {
    assert(newFlags == null || newFlags.length == items.length);
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userItemList'] = items;
    upsert['isNewItemList'] = newFlags ?? List.filled(items.length, '1').join();
  }

  /// 解锁歌曲/谱面时补一条 musicDetail 记录并标记为新增。
  /// 难度本身由 userItemList 的 itemKind 5/6/7 行表达（见客户端
  /// VOExtensions.ExportUserItems），不写在 musicDetail 上。
  void applyMusicDetailPatch(
    Map<String, dynamic> packet, {
    required Map<String, dynamic> musicData,
  }) {
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userMusicDetailList'] = [musicData];
    upsert['isNewMusicDetailList'] = '1';
  }

  /// 发放/更新旅行伙伴：写 `userCharacterList` 并给出逐行 `isNewCharacterList`。
  ///
  /// [newFlags] 省略时全部按「新增行」发（每位一个 '1'）。给已有角色改等级时
  /// 必须传 '0'，否则服务器按插入处理。客户端 `BuildListData` 就是按
  /// 「服务端是否已有同 characterId 的行」决定这一位是 0 还是 1 的。
  void applyCharacterListPatch(
    Map<String, dynamic> packet, {
    required List<Map<String, dynamic>> characters,
    String? newFlags,
  }) {
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userCharacterList'] = characters;
    upsert['isNewCharacterList'] =
        newFlags ?? List.filled(characters.length, '1').join();
  }

  /// 一键跑图：把区域标记为已完成，并让客户端自己把状态推回「已完成」。
  ///
  /// `UserMap.isClear` / `isComplete` 在客户端是从 `distance` 派生的
  /// （`MapMaster.CreateUserDataMapList` 拿 `distance` 与该区域的
  /// ReleaseFlag / End 里程针比较，没有对应针时甚至强制写回 false），
  /// 单发 flag 下次进区域选择页就会被冲掉。所以这里把 `distance` 直接推到
  /// `UserMapData.MaxDistance`，超过任何一张图的 End 针，flag 才站得住。
  ///
  /// `unlockFlag` 语义是反的：`IsFinishedOpening ? 0 : 1`，取 0 表示已开启。
  /// `isLock` 客户端不回读（`ConvertUserMap` 从不读它），给 false 只是保持上行一致。
  ///
  /// [newFlags] 每一位对应 [maps] 里的一行：'1' 新增、'0' 更新，
  /// 长度必须与 [maps] 一致（`BuildListData` 是一一对齐生成的）。
  void applyMapPatch(
    Map<String, dynamic> packet, {
    required List<Map<String, dynamic>> maps,
    required String newFlags,
  }) {
    assert(maps.length == newFlags.length);
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userMapList'] = maps;
    upsert['isNewMapList'] = newFlags;
  }

  /// 一行「已完成」的区域记录，字段与 `Net.VO.Mai2.UserMap` 一一对应。
  static Map<String, dynamic> completedMap(int mapId, {int? distance}) => {
    'mapId': mapId,
    'distance': distance ?? maxMapDistance,
    'isLock': false,
    'isClear': true,
    'isComplete': true,
    'unlockFlag': 0,
  };

  /// `UserMapData.MaxDistance = 999999999`，客户端认的最大步数。
  static const int maxMapDistance = 999999999;

  /// 万花筒：写 `userKaleidxScopeList` + `isNewKaleidxScopeList`。
  ///
  /// 每行是**整行替换**（15 个字段的 `UserKaleidxScope`），所以调用方必须先把
  /// 服务器上原行的成绩/日期字段读回来合并，不然 best 记录与 playCount 会被清零。
  ///
  /// 客户端 `ExportUserAll`（VOExtensions.cs:323）只在数组非空时才给这两个字段赋值，
  /// 空数组等于什么都没发；[newFlags] 长度必须等于 [scopes] 行数。
  void applyKaleidxScopePatch(
    Map<String, dynamic> packet, {
    required List<Map<String, dynamic>> scopes,
    required String newFlags,
  }) {
    assert(scopes.isNotEmpty);
    assert(scopes.length == newFlags.length);
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    upsert['userKaleidxScopeList'] = scopes;
    upsert['isNewKaleidxScopeList'] = newFlags;
  }

  /// 编组旅行伙伴：改 `userData[0].charaSlot`（int[5]，槽 0 为队长）。
  /// 客户端 ExportUserPlaylog 用同一份 CharaSlot 填 playlog 的
  /// characterId1..5，这里一起同步，避免 playlog 与 userData 互相矛盾。
  void applyCharaSlotPatch(
    Map<String, dynamic> packet, {
    required List<int> charaSlot,
  }) {
    final slots = normalizeCharaSlot(charaSlot);
    final upsert = packet['upsertUserAll'] as Map<String, dynamic>;
    final userDataList = upsert['userData'] as List;
    (userDataList.first as Map<String, dynamic>)['charaSlot'] = slots;

    for (final raw in (packet['userPlaylogList'] as List)) {
      final playlog = raw as Map<String, dynamic>;
      for (var i = 0; i < 5; i++) {
        playlog['characterId${i + 1}'] = slots[i];
      }
    }
  }

  /// 改总 Rating：只动 `userData.playerRating` 与 `userRating.rating`。
  ///
  /// `userRating.ratingList` / `newRatingList` 里每首歌各自的 Rating 原样带回，
  /// 不重排也不改值——服务器就是按这两处的和来出「乐曲 Rating」的。
  /// playlog 的 before/after 一起对齐，否则存档里那条记录会自相矛盾。
  void applyRatingPatch(
    Map<String, dynamic> packet, {
    required int rating,
  }) {
    final userData = _userDataOf(packet);
    final before = _toInt(userData['playerRating']);
    final value = rating.clamp(0, maxRating);
    userData['playerRating'] = value;

    final userRatingList =
        (packet['upsertUserAll'] as Map<String, dynamic>)['userRatingList']
            as List;
    // 整行换掉而不是原地写：userRating 在缺数据时是 `const {}`，改不了。
    if (userRatingList.first is Map<String, dynamic>) {
      userRatingList[0] = {
        ...(userRatingList.first as Map<String, dynamic>),
        'rating': value,
      };
    }

    for (final raw in (packet['userPlaylogList'] as List)) {
      final playlog = raw as Map<String, dynamic>;
      playlog['beforeRating'] = before;
      playlog['afterRating'] = value;
      playlog['beforeDeluxRating'] = before;
      playlog['afterDeluxRating'] = value;
    }
  }

  /// 改舞里程：`UserDetail.point` 是余额，`totalPoint` 是累计获得量。
  ///
  /// 客户端只在「获得」时把 point 钳到 99999（`UserDetail.AddMile`），
  /// 商店扣款走的是不带钳位的 `Point -= cost`，所以直接写更大的值不会被覆回；
  /// 展示就是一句 `num.ToString()`，没有位数上限。
  void applyMaiMilePatch(
    Map<String, dynamic> packet, {
    required int point,
    int? totalPoint,
  }) {
    final userData = _userDataOf(packet);
    userData['point'] = clampValue(point);
    if (totalPoint != null) {
      userData['totalPoint'] = clampValue(totalPoint);
    }
  }
}

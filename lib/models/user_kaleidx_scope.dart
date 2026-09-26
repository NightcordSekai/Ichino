/// `Net.VO.Mai2.UserKaleidxScope`（万花筒 / 宿命之门），走
/// `upsertUserAll.userKaleidxScopeList`，主键是 `gateId`。
///
/// 依据反编译客户端：
/// - 「发现门」与「获取钥匙」都在这同一张表里，分别是 `isGateFound` 与
///   `isKeyFound`。钥匙**不**走 `userItemList`——`ExportUserItems` 从不输出
///   itemKind 15，下行也没有 `GetUserItem(KaleidxScopeKey)` 这一步。
/// - 状态机在 `KaleidxScopeGateListController.cs:144-159`，四个组合里：
///   `!found &&  key` -> AnimState.None（**隐形**，不是锁着的门）
///   ` found && !key` -> Close（可见、未解锁）
///   ` found &&  key && !clear` -> Open（可挑战）
///   ` found &&  key &&  clear` -> Clear
///   所以只给钥匙不给门等于什么都没给。
class UserKaleidxScopeBean {
  final int gateId;
  final bool isGateFound;
  final bool isKeyFound;
  final bool isClear;
  final int totalRestLife;
  final int totalAchievement;

  /// 原样拼写是 `Deluxscore`（不是 `DeluxeScore`），改名服务器就认不出了。
  final int totalDeluxscore;
  final int bestAchievement;
  final int bestDeluxscore;
  final String bestAchievementDate;
  final String bestDeluxscoreDate;
  final int playCount;
  final String clearDate;
  final String lastPlayDate;
  final bool isInfoWatched;

  const UserKaleidxScopeBean({
    required this.gateId,
    this.isGateFound = false,
    this.isKeyFound = false,
    this.isClear = false,
    this.totalRestLife = 0,
    this.totalAchievement = 0,
    this.totalDeluxscore = 0,
    this.bestAchievement = 0,
    this.bestDeluxscore = 0,
    this.bestAchievementDate = '',
    this.bestDeluxscoreDate = '',
    this.playCount = 0,
    this.clearDate = '',
    this.lastPlayDate = '',
    this.isInfoWatched = false,
  });

  /// wire 上的完整 15 个字段。发出去的是整行替换，所以没列在这里的字段
  /// 必须从服务器原值带回来，否则会被清零。
  Map<String, dynamic> toWireJson() => {
    'gateId': gateId,
    'isGateFound': isGateFound,
    'isKeyFound': isKeyFound,
    'isClear': isClear,
    'totalRestLife': totalRestLife,
    'totalAchievement': totalAchievement,
    'totalDeluxscore': totalDeluxscore,
    'bestAchievement': bestAchievement,
    'bestDeluxscore': bestDeluxscore,
    'bestAchievementDate': bestAchievementDate,
    'bestDeluxscoreDate': bestDeluxscoreDate,
    'playCount': playCount,
    'clearDate': clearDate,
    'lastPlayDate': lastPlayDate,
    'isInfoWatched': isInfoWatched,
  };

  UserKaleidxScopeBean copyWith({
    bool? isGateFound,
    bool? isKeyFound,
    bool? isClear,
  }) => UserKaleidxScopeBean(
    gateId: gateId,
    isGateFound: isGateFound ?? this.isGateFound,
    isKeyFound: isKeyFound ?? this.isKeyFound,
    isClear: isClear ?? this.isClear,
    totalRestLife: totalRestLife,
    totalAchievement: totalAchievement,
    totalDeluxscore: totalDeluxscore,
    bestAchievement: bestAchievement,
    bestDeluxscore: bestDeluxscore,
    bestAchievementDate: bestAchievementDate,
    bestDeluxscoreDate: bestDeluxscoreDate,
    playCount: playCount,
    clearDate: clearDate,
    lastPlayDate: lastPlayDate,
    isInfoWatched: isInfoWatched,
  );

  /// 服务器上还没有这扇门时的新行。`isGateFound` 恒为 true——不存在「只给钥匙
  /// 不给门」这种可用状态（见类注释的状态机），新行其余字段取 struct 默认值。
  static UserKaleidxScopeBean discovered(int gateId, {required bool giveKey}) =>
      UserKaleidxScopeBean(
        gateId: gateId,
        isGateFound: true,
        isKeyFound: giveKey,
      );

  /// 在服务器原行上叠加本次动作。**必须**走这里而不是新建一行：整行替换会把
  /// best 成绩、playCount、clearDate 这些字段清零。
  UserKaleidxScopeBean withActions({
    required bool discover,
    required bool giveKey,
  }) => copyWith(
    // 给钥匙连带发现门，否则这行在客户端是隐形的。
    isGateFound: isGateFound || discover || giveKey,
    isKeyFound: isKeyFound || giveKey,
  );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  factory UserKaleidxScopeBean.fromJson(Map<String, dynamic> json) =>
      UserKaleidxScopeBean(
        gateId: _toInt(json['gateId']),
        isGateFound: _toBool(json['isGateFound']),
        isKeyFound: _toBool(json['isKeyFound']),
        isClear: _toBool(json['isClear']),
        totalRestLife: _toInt(json['totalRestLife']),
        totalAchievement: _toInt(json['totalAchievement']),
        totalDeluxscore: _toInt(json['totalDeluxscore']),
        bestAchievement: _toInt(json['bestAchievement']),
        bestDeluxscore: _toInt(json['bestDeluxscore']),
        bestAchievementDate: json['bestAchievementDate']?.toString() ?? '',
        bestDeluxscoreDate: json['bestDeluxscoreDate']?.toString() ?? '',
        playCount: _toInt(json['playCount']),
        clearDate: json['clearDate']?.toString() ?? '',
        lastPlayDate: json['lastPlayDate']?.toString() ?? '',
        isInfoWatched: _toBool(json['isInfoWatched']),
      );

  static List<UserKaleidxScopeBean> listFromResponse(
    Map<String, dynamic> json,
  ) {
    final raw = json['userKaleidxScopeList'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserKaleidxScopeBean.fromJson)
        .toList();
  }
}

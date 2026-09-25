/// GetUserRatingApi 的 `userRating` 结构，移植自 Empurple 的 `UserRatingData`。
///
/// 服务端已按 RA 排好 BEST 35 / BEST 15，客户端不再重排。
enum MusicLevel {
  basic,
  advanced,
  expert,
  master,
  reMaster;

  static MusicLevel fromInt(int level) =>
      level >= 0 && level < MusicLevel.values.length
          ? MusicLevel.values[level]
          : MusicLevel.basic;
}

class UserRatingItemBean {
  final int musicId;
  final int level;
  final int achievement;
  final int comboStatus;
  final int syncStatus;
  final int romVersion;

  const UserRatingItemBean({
    required this.musicId,
    required this.level,
    required this.achievement,
    required this.comboStatus,
    required this.syncStatus,
    required this.romVersion,
  });

  /// 达成率百分比数值，接口原值 1001234 => 100.1234。
  double get achievementPercent => achievement / 10000.0;

  /// 对应 Empurple 的 `formatRatingSimple`。
  String get achievementText => '${achievementPercent.toStringAsFixed(4)}%';

  /// DX 谱的 musicId 会加 10000 偏移。
  bool get isDx => musicId > 10000;

  MusicLevel get musicLevel => MusicLevel.fromInt(level);

  factory UserRatingItemBean.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return UserRatingItemBean(
      musicId: toInt(json['musicId']),
      level: toInt(json['level']),
      achievement: toInt(json['achievement']),
      comboStatus: toInt(json['comboStatus']),
      syncStatus: toInt(json['syncStatus']),
      romVersion: toInt(json['romVersion']),
    );
  }
}

class UserRatingBean {
  final int userId;
  final List<UserRatingItemBean> ratingList;
  final List<UserRatingItemBean> newRatingList;

  const UserRatingBean({
    required this.userId,
    required this.ratingList,
    required this.newRatingList,
  });

  static List<UserRatingItemBean> _parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserRatingItemBean.fromJson)
        .toList();
  }

  factory UserRatingBean.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final userRating =
        (json['userRating'] as Map<String, dynamic>?) ?? const {};

    return UserRatingBean(
      userId: toInt(json['userId']),
      ratingList: _parseList(userRating['ratingList']),
      newRatingList: _parseList(userRating['newRatingList']),
    );
  }
}

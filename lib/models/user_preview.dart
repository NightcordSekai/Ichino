class UserPreviewDataBean {
  final int userId;
  final String userName;
  final bool isLogin;
  final String lastGameId;
  final String lastRomVersion;
  final String lastDataVersion;
  final String lastLoginDate;
  final String lastPlayDate;
  final int playerRating;
  final int nameplateId;
  final int iconId;
  final int trophyId;
  final bool isNetMember;
  final bool isInherit;
  final int totalAwake;
  final int dispRate;
  final String dailyBonusDate;
  final int headPhoneVolume;
  final int banState;
  final int errorId;

  const UserPreviewDataBean({
    required this.userId,
    required this.userName,
    required this.isLogin,
    required this.lastGameId,
    required this.lastRomVersion,
    required this.lastDataVersion,
    required this.lastLoginDate,
    required this.lastPlayDate,
    required this.playerRating,
    required this.nameplateId,
    required this.iconId,
    required this.trophyId,
    required this.isNetMember,
    required this.isInherit,
    required this.totalAwake,
    required this.dispRate,
    required this.dailyBonusDate,
    required this.headPhoneVolume,
    required this.banState,
    required this.errorId,
  });

  factory UserPreviewDataBean.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is double) return v.toInt();
      return 0;
    }

    bool toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    String toStr(dynamic v) => v?.toString() ?? '';

    return UserPreviewDataBean(
      userId: toInt(json['userId']),
      userName: toStr(json['userName']),
      isLogin: toBool(json['isLogin']),
      lastGameId: toStr(json['lastGameId']),
      lastRomVersion: toStr(json['lastRomVersion']),
      lastDataVersion: toStr(json['lastDataVersion']),
      lastLoginDate: toStr(json['lastLoginDate']),
      lastPlayDate: toStr(json['lastPlayDate']),
      playerRating: toInt(json['playerRating']),
      nameplateId: toInt(json['nameplateId']),
      iconId: toInt(json['iconId']),
      trophyId: toInt(json['trophyId']),
      isNetMember: toBool(json['isNetMember']),
      isInherit: toBool(json['isInherit']),
      totalAwake: toInt(json['totalAwake']),
      dispRate: toInt(json['dispRate']),
      dailyBonusDate: toStr(json['dailyBonusDate']),
      headPhoneVolume: (json['headPhoneVolume'] is String)
          ? (int.tryParse(json['headPhoneVolume']) ?? 0)
          : toInt(json['headPhoneVolume']),
      banState: toInt(json['banState']),
      errorId: toInt(json['errorId']),
    );
  }
}

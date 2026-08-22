class UserDataBean {
  final int userId;
  final String userName;
  final String? friendCode;
  final bool isNetMember;
  final int point;
  final int totalPoint;
  final int playerRating;
  final int playerOldRating;
  final int playerNewRating;
  final int highestRating;
  final int musicRating;
  final int gradeRank;
  final int courseRank;
  final int classRank;
  final int nameplateId;
  final int frameId;
  final int iconId;
  final int trophyId;
  final int plateId;
  final int titleId;
  final int partnerId;
  final int playCount;
  final int currentPlayCount;
  final int totalSync;
  final int totalAchievement;
  final int totalDeluxscore;
  final int totalAwake;
  final String lastGameId;
  final String lastRomVersion;
  final String lastDataVersion;
  final String lastLoginDate;
  final String lastPlayDate;
  final String firstGameId;
  final String firstRomVersion;
  final String firstDataVersion;
  final String firstPlayDate;
  final String lastRegionName;
  final int lastRegionId;
  final String dailyBonusDate;
  final int banState;

  const UserDataBean({
    required this.userId,
    required this.userName,
    required this.friendCode,
    required this.isNetMember,
    required this.point,
    required this.totalPoint,
    required this.playerRating,
    required this.playerOldRating,
    required this.playerNewRating,
    required this.highestRating,
    required this.musicRating,
    required this.gradeRank,
    required this.courseRank,
    required this.classRank,
    required this.nameplateId,
    required this.frameId,
    required this.iconId,
    required this.trophyId,
    required this.plateId,
    required this.titleId,
    required this.partnerId,
    required this.playCount,
    required this.currentPlayCount,
    required this.totalSync,
    required this.totalAchievement,
    required this.totalDeluxscore,
    required this.totalAwake,
    required this.lastGameId,
    required this.lastRomVersion,
    required this.lastDataVersion,
    required this.lastLoginDate,
    required this.lastPlayDate,
    required this.firstGameId,
    required this.firstRomVersion,
    required this.firstDataVersion,
    required this.firstPlayDate,
    required this.lastRegionName,
    required this.lastRegionId,
    required this.dailyBonusDate,
    required this.banState,
  });

  factory UserDataBean.fromJson(Map<String, dynamic> json) {
    final ud = (json['userData'] as Map<String, dynamic>?) ?? const {};

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    bool toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    String toStr(dynamic v) => v?.toString() ?? '';

    return UserDataBean(
      userId: toInt(json['userId']),
      userName: toStr(ud['userName']),
      friendCode: ud['friendCode']?.toString(),
      isNetMember: toBool(ud['isNetMember']),
      point: toInt(ud['point']),
      totalPoint: toInt(ud['totalPoint']),
      playerRating: toInt(ud['playerRating']),
      playerOldRating: toInt(ud['playerOldRating']),
      playerNewRating: toInt(ud['playerNewRating']),
      highestRating: toInt(ud['highestRating']),
      musicRating: toInt(ud['musicRating']),
      gradeRank: toInt(ud['gradeRank']),
      courseRank: toInt(ud['courseRank']),
      classRank: toInt(ud['classRank']),
      nameplateId: toInt(ud['nameplateId']),
      frameId: toInt(ud['frameId']),
      iconId: toInt(ud['iconId']),
      trophyId: toInt(ud['trophyId']),
      plateId: toInt(ud['plateId']),
      titleId: toInt(ud['titleId']),
      partnerId: toInt(ud['partnerId']),
      playCount: toInt(ud['playCount']),
      currentPlayCount: toInt(ud['currentPlayCount']),
      totalSync: toInt(ud['totalSync']),
      totalAchievement: toInt(ud['totalAchievement']),
      totalDeluxscore: toInt(ud['totalDeluxscore']),
      totalAwake: toInt(ud['totalAwake']),
      lastGameId: toStr(ud['lastGameId']),
      lastRomVersion: toStr(ud['lastRomVersion']),
      lastDataVersion: toStr(ud['lastDataVersion']),
      lastLoginDate: toStr(ud['lastLoginDate']),
      lastPlayDate: toStr(ud['lastPlayDate']),
      firstGameId: toStr(ud['firstGameId']),
      firstRomVersion: toStr(ud['firstRomVersion']),
      firstDataVersion: toStr(ud['firstDataVersion']),
      firstPlayDate: toStr(ud['firstPlayDate']),
      lastRegionName: toStr(ud['lastRegionName']),
      lastRegionId: toInt(ud['lastRegionId']),
      dailyBonusDate: toStr(ud['dailyBonusDate']),
      banState: toInt(json['banState']),
    );
  }
}
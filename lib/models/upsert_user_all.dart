class UserCharacter {
  int characterId;
  int level;
  int awakening;
  int useCount;

  UserCharacter({
    required this.characterId,
    this.level = 1,
    this.awakening = 0,
    this.useCount = 0,
  });

  factory UserCharacter.fromJson(Map<String, dynamic> json) {
    return UserCharacter(
      characterId: (json['characterId'] as num).toInt(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      awakening: (json['awakening'] as num?)?.toInt() ?? 0,
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'level': level,
        'awakening': awakening,
        'useCount': useCount,
      };
}

/// The full UpsertUserAll API payload, constructed from fetched user data
/// and editable fields (charaSlot, charaLockSlot, character levels).
class UpsertUserAllPayload {
  final int userId;
  final int playlogId;
  final bool isEventMode;
  final bool isFreePlay;
  final int loginDateTime;

  /// The entire [upsertUserAll] sub-object from the JSON.
  final Map<String, dynamic> upsertUserAll;

  /// Editable character slots (5 elements).
  final List<int> charaSlot;

  /// Editable locked character slots (5 elements).
  final List<int> charaLockSlot;

  /// Editable character list.
  final List<UserCharacter> userCharacterList;

  /// Minimal playlog entry (required — server rejects empty playlogList).
  final Map<String, dynamic>? userPlaylog;

  const UpsertUserAllPayload({
    required this.userId,
    required this.playlogId,
    this.isEventMode = false,
    this.isFreePlay = false,
    required this.loginDateTime,
    required this.upsertUserAll,
    required this.charaSlot,
    required this.charaLockSlot,
    required this.userCharacterList,
    this.userPlaylog,
  });

  /// Serialize to the JSON packet expected by UpsertUserAllApi.
  Map<String, dynamic> toJson() {
    final copy = Map<String, dynamic>.from(upsertUserAll);
    final userData = List<Map<String, dynamic>>.from(
      (copy['userData'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    userData[0]['charaSlot'] = charaSlot;
    userData[0]['charaLockSlot'] = charaLockSlot;
    copy['userData'] = userData;
    copy['userCharacterList'] =
        userCharacterList.map((c) => c.toJson()).toList();

    return {
      'userId': userId,
      'playlogId': playlogId,
      'isEventMode': isEventMode,
      'isFreePlay': isFreePlay,
      'loginDateTime': loginDateTime,
      'userPlaylogList': userPlaylog != null ? [userPlaylog] : <dynamic>[],
      'upsertUserAll': copy,
    };
  }
}

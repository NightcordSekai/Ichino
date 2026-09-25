/// GetUserRatingApi 之外的角色（旅行伙伴）数据。
///
/// 对应客户端 `Net.VO.Mai2.UserCharacter`：只有 4 个字段，走
/// `UpsertUserAllApi` 的 `upsertUserAll.userCharacterList`，主键是
/// `characterId`（见 VOExtensions.cs:265 的 BuildListData 比较器）。
///
/// 注意：旅行伙伴不是「搭档」。搭档是 ItemKind.Partner = 10，走 userItemList；
/// 角色是 ItemKind.Character = 9，客户端的 ExportUserItems() 并不导出它，
/// 角色的拥有状态由 userCharacterList 表达。
class UserCharacterBean {
  final int characterId;
  final int level;
  final int awakening;
  final int useCount;

  const UserCharacterBean({
    required this.characterId,
    required this.level,
    required this.awakening,
    required this.useCount,
  });

  /// wire 上的 UserCharacter，字段与顺序与客户端声明一致。
  Map<String, dynamic> toWireJson() => {
    'characterId': characterId,
    'level': level,
    'awakening': awakening,
    'useCount': useCount,
  };

  UserCharacterBean copyWith({int? level, int? awakening, int? useCount}) =>
      UserCharacterBean(
        characterId: characterId,
        level: level ?? this.level,
        awakening: awakening ?? this.awakening,
        useCount: useCount ?? this.useCount,
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory UserCharacterBean.fromJson(Map<String, dynamic> json) =>
      UserCharacterBean(
        characterId: _toInt(json['characterId']),
        level: _toInt(json['level']),
        awakening: _toInt(json['awakening']),
        useCount: _toInt(json['useCount']),
      );

  static List<UserCharacterBean> listFromResponse(Map<String, dynamic> json) {
    final raw = json['userCharacterList'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserCharacterBean.fromJson)
        .toList();
  }
}

/// `UserDetail.charaSlot` 固定 5 个槽，槽 0 是队长
/// （客户端 CharactorSlotController.cs:27 对 i==0 用 leaderCharaSlotPrefab）。
List<int> normalizeCharaSlot(List<int> slots) =>
    List<int>.generate(5, (i) => i < slots.length ? slots[i] : 0);

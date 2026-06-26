/// The full UpsertUserAll API payload, constructed from fetched user data
/// and an editable single-song score.
class UpsertUserAllPayload {
  final int userId;
  final int playlogId;
  final bool isEventMode;
  final bool isFreePlay;
  final int loginDateTime;

  /// The entire [upsertUserAll] sub-object from the JSON.
  final Map<String, dynamic> upsertUserAll;

  /// Minimal playlog entry (required — server rejects empty playlogList).
  final Map<String, dynamic>? userPlaylog;

  const UpsertUserAllPayload({
    required this.userId,
    required this.playlogId,
    this.isEventMode = false,
    this.isFreePlay = false,
    required this.loginDateTime,
    required this.upsertUserAll,
    this.userPlaylog,
  });

  /// Serialize to the JSON packet expected by UpsertUserAllApi.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'playlogId': playlogId,
      'isEventMode': isEventMode,
      'isFreePlay': isFreePlay,
      'loginDateTime': loginDateTime,
      'userPlaylogList': userPlaylog != null ? [userPlaylog] : <dynamic>[],
      'upsertUserAll': upsertUserAll,
    };
  }
}

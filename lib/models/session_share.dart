import 'dart:convert';

/// 实验性：一次登录的可搬运快照（用户 ID + JSESSIONID Cookie + 令牌），
/// 编码方式是 Base64(JSON)，用于在别的设备上恢复会话、免重新扫码。
///
/// 没有任何加密，字符串在谁手里谁就能操作这个账号，只适合自己传递。
class SessionShare {
  static const String _kind = 'ichino.session';
  static const int _version = 1;

  final int userId;
  final String token;

  /// 原始 Cookie 串，可能是 `JSESSIONID=...`，也可能带别的字段。
  final String? cookie;

  const SessionShare({required this.userId, required this.token, this.cookie});

  /// 只取 `JSESSIONID`：传输层后续请求就靠它维持会话
  /// （见 `TitleApiService._captureCookiesFromResponse`）。
  String? get jsessionid {
    final raw = cookie;
    if (raw == null) return null;
    for (final part in raw.split(';')) {
      final pair = part.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      if (pair.substring(0, eq).toUpperCase() != 'JSESSIONID') continue;
      final value = pair.substring(eq + 1).trim();
      return value.isEmpty ? null : 'JSESSIONID=$value';
    }
    return null;
  }

  bool get hasCookie => jsessionid != null;
  bool get hasToken => token.isNotEmpty;

  String encode() {
    final map = <String, dynamic>{
      'kind': _kind,
      'version': _version,
      'userId': userId,
      'token': token,
      'cookie': jsessionid,
    };
    return base64Encode(utf8.encode(jsonEncode(map)));
  }

  /// 不是连接信息时返回 `null`——登录页靠它区分 QR 令牌和会话快照。
  static SessionShare? tryDecode(String input) {
    var text = input.replaceAll(RegExp(r'\s'), '');
    if (text.length < 16) return null;
    final pad = text.length % 4;
    if (pad != 0) text += '=' * (4 - pad);

    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(text)));
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['kind'] != _kind) return null;
      if ((decoded['version'] as num?)?.toInt() != _version) return null;

      final share = SessionShare(
        userId: (decoded['userId'] as num?)?.toInt() ?? 0,
        token: decoded['token'] as String? ?? '',
        cookie: decoded['cookie'] as String?,
      );
      // 两头都空的话这串信息什么都恢复不了。
      if (share.userId <= 0 || (!share.hasCookie && !share.hasToken)) {
        return null;
      }
      return share;
    } catch (_) {
      return null;
    }
  }
}

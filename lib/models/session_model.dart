import 'package:flutter/foundation.dart';

import '../config/title_server_config.dart';
import '../services/api_service.dart';
import '../services/title_api_service.dart';
import 'session_share.dart';
import 'user_data.dart';

/// [SessionModel.restoreFromShare] 的结果。
class SessionRestoreResult {
  /// `true` 表示沿用了连接信息里的 JSESSIONID；`false` 表示用令牌重新登录，
  /// 拿到了一份新 Cookie。
  final bool reusedCookie;

  /// 沿用旧会话时顺带拉到的用户数据（HomePage 直接展示，省一次请求）。
  final UserDataBean? userData;

  const SessionRestoreResult({required this.reusedCookie, this.userData});
}

class SessionModel extends ChangeNotifier {
  static final SessionModel instance = SessionModel._();

  SessionModel._();

  final ApiService _apiService = ApiService();

  LoginResult? _loginResult;
  UserLoginResult? _gameLogin;
  String? _cookies;

  LoginResult? get loginResult => _loginResult;
  UserLoginResult? get gameLogin => _gameLogin;
  String? get cookies => _cookies;

  static String extractQRCode(String qrCodeToken) =>
      ApiService.extractQRCode(qrCodeToken);

  Future<LoginResult> loginWithQr(String qrCodeToken) async {
    final result = await _apiService.login(qrCodeToken);
    if (result.success) {
      _loginResult = result;
      notifyListeners();
    }
    return result;
  }

  Future<UserLoginResult> loginGame({
    required int userId,
    required String token,
  }) async {
    final config = TitleServerConfigHolder().config;
    if (config == null) {
      throw const TitleApiException('Title Server 未配置');
    }
    // Session cookie comes from the UserLoginApi response itself (empurple).
    final service = TitleApiService(config);
    final login = await service.userLoginFull(userId: userId, token: token);
    updateCookies(service.cookies);
    _gameLogin = login;
    notifyListeners();
    return login;
  }

  Future<void> logoutGame({required int userId, String? cookies}) async {
    final login = _gameLogin;
    if (login == null) return;
    final config = TitleServerConfigHolder().config;
    if (config == null) return;

    final service = TitleApiService(config, cookies: cookies ?? _cookies);
    try {
      await service.userLogout(
        userId: userId,
        loginDateTime: login.loginDateTime,
      );
    } catch (_) {
      // best-effort
    }
    _gameLogin = null;
    notifyListeners();
  }

  void setGameLogin(UserLoginResult? login) {
    _gameLogin = login;
    notifyListeners();
  }

  /// 实验性：导出连接信息（用户 ID + JSESSIONID + 令牌）。
  SessionShare exportConnectionInfo({
    required int userId,
    required String token,
  }) => SessionShare(userId: userId, token: token, cookie: _cookies);

  /// 实验性：用连接信息恢复会话。
  ///
  /// 带着可用的 JSESSIONID 时沿用这个会话继续交互，不重发 `UserLoginApi`；
  /// 没有 Cookie 或 Cookie 已失效，才退回去用令牌登录一次拿新 Cookie。
  Future<SessionRestoreResult> restoreFromShare(SessionShare share) async {
    final cookie = share.jsessionid;
    if (cookie != null) {
      final userData = await _probeCookieSession(share.userId, cookie);
      if (userData != null) {
        // _gameLogin 保持 null：这次没有 UserLoginApi，拿不到 loginId /
        // loginDateTime，写入类功能页照旧提示「尚未登录游戏服务器」。
        notifyListeners();
        return SessionRestoreResult(reusedCookie: true, userData: userData);
      }
    }

    if (!share.hasToken) {
      throw const TitleApiException('连接信息里的 Cookie 已失效，且没有可用于重新登录的令牌');
    }
    await loginGame(userId: share.userId, token: share.token);
    return const SessionRestoreResult(reusedCookie: false);
  }

  /// 用导入的 Cookie 试拉一次 GetUserDataApi，会话不可用时返回 `null`。
  Future<UserDataBean?> _probeCookieSession(int userId, String cookie) async {
    final service = TitleApiService.fromHolder(cookies: cookie);
    if (service == null) return null;
    try {
      final json = await service.getUserData(userId);
      // 会话失效时服务器仍可能回一个不含 userData 的包，不能当成登录成功。
      if (json['userData'] is! Map) return null;
      final userData = UserDataBean.fromJson(json);
      updateCookies(service.cookies);
      return userData;
    } on TitleApiException {
      return null;
    }
  }

  void updateCookies(String? cookies) {
    if (cookies != null && cookies.isNotEmpty) {
      _cookies = cookies;
    }
  }

  void reset() {
    _loginResult = null;
    _gameLogin = null;
    _cookies = null;
    notifyListeners();
  }
}

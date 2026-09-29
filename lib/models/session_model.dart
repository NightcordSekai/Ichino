import 'package:flutter/foundation.dart';

import '../config/title_server_config.dart';
import '../services/api_service.dart';
import '../services/title_api_service.dart';
import 'session_share.dart';
import 'user_data.dart';
import 'user_preview.dart';

/// [SessionModel.restoreFromShare] 的结果。
class SessionRestoreResult {
  /// `true` 表示沿用了连接信息里的 JSESSIONID；`false` 表示用令牌重新登录，
  /// 拿到了一份新 Cookie。
  final bool reusedCookie;

  /// 沿用旧会话时顺带拉到的用户数据与概要（HomePage 直接展示，省一次请求）。
  final UserDataBean? userData;
  final UserPreviewDataBean? preview;

  /// 服务器认为这次会话仍在登录中（`preview.isLogin`），或刚用令牌登录成功。
  /// 只有为 `true` 时票据与风险页才开放写入，并且照常吃 60 秒登录后冷却。
  final bool loggedIn;

  const SessionRestoreResult({
    required this.reusedCookie,
    this.userData,
    this.preview,
    this.loggedIn = false,
  });
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
  }) => SessionShare(
    userId: userId,
    token: token,
    loginId: _gameLogin?.loginId ?? 0,
    cookie: _cookies,
  );

  /// 实验性：用连接信息恢复会话。
  ///
  /// 带着可用的 JSESSIONID 时沿用这个会话继续交互，不重发 `UserLoginApi`；
  /// 没有 Cookie 或 Cookie 已失效，才退回去用令牌登录一次拿新 Cookie。
  Future<SessionRestoreResult> restoreFromShare(SessionShare share) async {
    final cookie = share.jsessionid;
    if (cookie != null) {
      final resumed = await _resumeCookieSession(share, cookie);
      if (resumed != null) {
        notifyListeners();
        return resumed;
      }
    }

    if (!share.hasToken) {
      throw const TitleApiException('连接信息里的 Cookie 已失效，且没有可用于重新登录的令牌');
    }
    await loginGame(userId: share.userId, token: share.token);
    // UserLoginApi 成功了，登录态直接可用，照常吃登录后 60 秒冷却。
    return const SessionRestoreResult(reusedCookie: false, loggedIn: true);
  }

  /// 沿用连接信息里的 JSESSIONID 继续这次会话；服务器已经不认这份 Cookie 时
  /// 返回 `null`，由调用方退回去用令牌重新登录。
  Future<SessionRestoreResult?> _resumeCookieSession(
    SessionShare share,
    String cookie,
  ) async {
    final service = TitleApiService.fromHolder(cookies: cookie);
    if (service == null) return null;

    try {
      final json = await service.getUserData(share.userId);
      // 会话失效时服务器仍可能回一个不含 userData 的包，不能当成登录成功。
      if (json['userData'] is! Map) return null;
      final userData = UserDataBean.fromJson(json);

      UserPreviewDataBean? preview;
      if (share.hasToken) {
        // isLogin 是服务器对「这次会话还挂在机上」的判定，风险页要用的 loginId
        // 也在这里。令牌过期拉不到 preview 就只放开读取，按未登录处理。
        try {
          preview = await service.getUserPreview(
            userId: share.userId,
            token: share.token,
          );
        } on TitleApiException {
          preview = null;
        }
      }
      updateCookies(service.cookies);

      // 服务器说这次会话还挂在机上，就按已登录处理：loginDateTime 取当下，
      // 风险页与票据照常吃「登录后 60 秒冷却」，不用重新 UserLoginApi。
      if (preview != null && preview.isLogin) {
        _gameLogin = UserLoginResult(
          token: share.token,
          // 优先用导出端带过来的 loginId（那是服务器给这次登录的真实 id），
          // 导出端没有才退回 preview 里的字段。
          loginId: share.loginId != 0 ? share.loginId : preview.loginId,
          lastLoginDate: preview.lastLoginDate,
          loginDateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }

      return SessionRestoreResult(
        reusedCookie: true,
        userData: userData,
        preview: preview,
        loggedIn: _gameLogin != null,
      );
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

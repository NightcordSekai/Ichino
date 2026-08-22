import 'package:flutter/foundation.dart';

import '../config/title_server_config.dart';
import '../services/api_service.dart';
import '../services/title_api_service.dart';

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

  Future<void> logoutGame({
    required int userId,
    String? cookies,
  }) async {
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

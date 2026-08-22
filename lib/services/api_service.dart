import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/title_server_config.dart';

class LoginResult {
  final bool success;
  final int errorId;
  final int userId;
  final String token;

  const LoginResult({
    required this.success,
    required this.errorId,
    required this.userId,
    required this.token,
  });
}

class ApiService {
  final TitleServerConfig? _config;

  ApiService([this._config]);

  TitleServerConfig? get _cfg => _config ?? TitleServerConfigHolder().config;
  String get _chipId => _cfg?.keychipId ?? '';
  String get _aimeSalt => _cfg?.aimeSalt ?? '';
  String get _aimeUrl => _cfg?.aimeUrl ?? '';
  String get _openGameID {
    final v = _cfg?.openGameID;
    return (v != null && v.isNotEmpty) ? v : 'MAID';
  }

  String _formatTimestamp() {
    final tokyo = DateTime.now().toUtc().add(const Duration(hours: 9));
    final y = (tokyo.year % 100).toString().padLeft(2, '0');
    final M = tokyo.month.toString().padLeft(2, '0');
    final d = tokyo.day.toString().padLeft(2, '0');
    final h = tokyo.hour.toString().padLeft(2, '0');
    final m = tokyo.minute.toString().padLeft(2, '0');
    final s = tokyo.second.toString().padLeft(2, '0');
    return '$y$M$d$h$m$s';
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static String extractQRCode(String qrCodeToken) {
    if (qrCodeToken.length > 64) {
      return qrCodeToken.substring(qrCodeToken.length - 64);
    }
    return qrCodeToken;
  }

  Future<LoginResult> login(String qrCodeToken) async {
    final timestamp = _formatTimestamp();
    final qrCode = extractQRCode(qrCodeToken);
    final chipId = _chipId;
    final rawKey = chipId + timestamp + _aimeSalt;
    final key = _sha256(rawKey).toUpperCase();

    final body = jsonEncode({
      'chipID': chipId,
      'openGameID': _openGameID,
      'key': key,
      'qrCode': qrCode,
      'timestamp': timestamp,
    });

    // ignore: avoid_print
    print('[login] POST $_aimeUrl');
    // ignore: avoid_print
    print('[login] chipId=$chipId openGameID=$_openGameID');

    final response = await http
        .post(
          Uri.parse(_aimeUrl),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'WC_AIME_LIB',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    final obj = jsonDecode(response.body) as Map<String, dynamic>;
    final errorId = obj['errorID'] as int? ?? -1;
    final userId = obj['userID'] as int? ?? -1;
    final token = obj['token'] as String? ?? '';

    // Session cookies (JSESSIONID) are captured from the title server's
    // UserLoginApi response, not from the Aime server — see empurple.

    return LoginResult(
      success: errorId == 0,
      errorId: errorId,
      userId: userId,
      token: token,
    );
  }
}

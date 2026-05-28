import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class LoginResult {
  final bool success;
  final int errorId;
  final int userId;
  final String token;
  final String? cookies;

  const LoginResult({
    required this.success,
    required this.errorId,
    required this.userId,
    required this.token,
    this.cookies,
  });
}

class ApiService {
  static const String chimeSalt = 'XcW5FW4cPArBXEk4vzKz3CIrMuA5EVVW';
  static const String baseUrl = 'http://ai.sys-allnet.cn';

  String chipId;

  ApiService({this.chipId = 'A63E-01C28055905'});

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

  String extractQRCode(String qrCodeToken) {
    if (qrCodeToken.length > 64) {
      return qrCodeToken.substring(qrCodeToken.length - 64);
    }
    return qrCodeToken;
  }

  Future<LoginResult> login(String qrCodeToken) async {
    final timestamp = _formatTimestamp();
    final qrCode = extractQRCode(qrCodeToken);
    final rawKey = chipId + timestamp + chimeSalt;
    final key = _sha256(rawKey).toUpperCase();

    final body = jsonEncode({
      'chipID': chipId,
      'openGameID': 'MAID',
      'key': key,
      'qrCode': qrCode,
      'timestamp': timestamp,
    });

    final response = await http
        .post(
          Uri.parse('$baseUrl/wc_aime/api/get_data'),
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

    // ── Extract ALL cookies from response headers ──
    // On web, Set-Cookie is a forbidden response header (browser hides it).
    // On native (dart:io), it appears as lowercase 'set-cookie'.
    // The http package may join multiple Set-Cookie lines with ', '.
    String? cookies;

    // ignore: avoid_print
    print('[login] ── Response headers (${response.headers.length} entries) ──');
    final headerKeys = response.headers.keys.toList();
    for (final key in headerKeys) {
      final value = response.headers[key]!;
      // ignore: avoid_print
      print('[login]   "$key": "$value"');

      // Match any header name that smells like a cookie
      final lower = key.toLowerCase();
      if (lower.contains('cookie') || lower.contains('set-cookie')) {
        cookies = value;
        // ignore: avoid_print
        print('[login] >>> Found cookie header: $key = $cookies');
      }
    }

    // Also try direct lookup with various casings (just in case iteration misses)
    if (cookies == null) {
      for (final name in ['set-cookie', 'Set-Cookie', 'SET-COOKIE', 'cookie', 'Cookie', 'COOKIE']) {
        final v = response.headers[name];
        if (v != null && v.isNotEmpty) {
          cookies = v;
          // ignore: avoid_print
          print('[login] >>> Direct lookup "$name" = $cookies');
          break;
        }
      }
    }

    if (cookies == null) {
      // ignore: avoid_print
      print('[login] WARNING: No cookie/set-cookie header found in response.');
      // Also check if response body has session info
      if (obj.containsKey('jsessionId')) {
        cookies = 'JSESSIONID=${obj['jsessionId']}';
        // ignore: avoid_print
        print('[login] >>> Found jsessionId in response body: $cookies');
      } else if (obj.containsKey('sessionId')) {
        cookies = 'JSESSIONID=${obj['sessionId']}';
        // ignore: avoid_print
        print('[login] >>> Found sessionId in response body: $cookies');
      }
    }

    // Parse out individual cookie name=value pairs for clean forwarding
    // (strip Path, HttpOnly, etc. attributes)
    String? cleanCookies;
    if (cookies != null) {
      final parts = <String>[];
      // Split on ', ' first (http package combines multiple Set-Cookie headers)
      // Then split on '\n' (some server responses use newlines)
      for (final chunk in cookies.split(RegExp(r', |\n'))) {
        final trimmed = chunk.trim();
        if (trimmed.isEmpty) continue;
        // Extract "NAME=VALUE" before the first ';'
        final semi = trimmed.indexOf(';');
        final nv = semi > 0 ? trimmed.substring(0, semi) : trimmed;
        if (nv.contains('=')) {
          parts.add(nv);
        }
      }
      cleanCookies = parts.join('; ');
      // ignore: avoid_print
      print('[login] Clean cookies to forward: $cleanCookies');
    }

    return LoginResult(
      success: errorId == 0,
      errorId: errorId,
      userId: userId,
      token: token,
      cookies: cleanCookies,
    );
  }
}

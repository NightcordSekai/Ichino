import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

import '../config/title_server_config.dart';
import '../models/user_data.dart';
import '../models/user_preview.dart';

class TitleApiException implements Exception {
  final String message;
  const TitleApiException(this.message);
  @override
  String toString() => 'TitleApiException: $message';
}

class UserLoginResult {
  final String token;
  final int loginId;
  final String lastLoginDate;
  final int loginDateTime;

  const UserLoginResult({
    required this.token,
    required this.loginId,
    required this.lastLoginDate,
    required this.loginDateTime,
  });
}

class TitleApiService {
  static const String _obfuscateConstant = 'MaimaiChn';

  static String? lastRawResponse;

  final TitleServerConfig _config;
  String? _cookies;

  TitleApiService(this._config, {String? cookies}) : _cookies = cookies;

  String? get cookies => _cookies;

  Uint8List _aesEncrypt(Uint8List plaintext) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(_config.aesKeyBytes)),
            Uint8List.fromList(_config.aesIvBytes),
          ),
          null,
        ),
      );
    return cipher.process(plaintext);
  }

  Uint8List _aesDecrypt(Uint8List ciphertext) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(_config.aesKeyBytes)),
            Uint8List.fromList(_config.aesIvBytes),
          ),
          null,
        ),
      );
    return cipher.process(ciphertext);
  }

  Uint8List _compress(List<int> data) {
    return Uint8List.fromList(ZLibEncoder().encode(data));
  }

  Uint8List _decompress(List<int> data) {
    return Uint8List.fromList(ZLibDecoder().decodeBytes(data));
  }

  Uint8List _buildRequestBody(Map<String, dynamic> packet) {
    final jsonStr = jsonEncode(packet);
    final jsonBytes = utf8.encode(jsonStr);
    final compressed = _compress(jsonBytes);
    return _aesEncrypt(compressed);
  }

  void _captureCookiesFromResponse(http.Response response, String apiName) {
    // ignore: avoid_print
    print('[$apiName] ── Response headers (${response.headers.length} entries) ──');
    final headerKeys = response.headers.keys.toList();
    String? rawCookies;
    for (final key in headerKeys) {
      final value = response.headers[key]!;
      // ignore: avoid_print
      print('[$apiName]   "$key": "$value"');
      final lower = key.toLowerCase();
      if (lower.contains('set-cookie') || lower.contains('cookie')) {
        rawCookies = value;
        // ignore: avoid_print
        print('[$apiName] >>> Found cookie header: $key = $rawCookies');
      }
    }

    if (rawCookies != null) {
      // Parse JSESSIONID from the cookie value
      // The jsessionid cookie is the session key from WaCa
      final parts = <String>[];
      for (final chunk in rawCookies.split(RegExp(r', |\n'))) {
        final trimmed = chunk.trim();
        if (trimmed.isEmpty) continue;
        final semi = trimmed.indexOf(';');
        final nv = semi > 0 ? trimmed.substring(0, semi) : trimmed;
        if (nv.contains('=')) {
          parts.add(nv);
          final eq = nv.indexOf('=');
          final name = nv.substring(0, eq);
          final value = nv.substring(eq + 1);
          // ignore: avoid_print
          print('[$apiName] >>> Cookie pair: $name = $value');
        }
      }
      final cleanCookies = parts.join('; ');
      if (cleanCookies.isNotEmpty) {
        _cookies = cleanCookies;
        // ignore: avoid_print
        print('[$apiName] >>> Stored cookies for subsequent requests: $_cookies');
      }
    }
  }

  Map<String, dynamic> _processResponseBody(Uint8List bodyBytes) {
    try {
      final decrypted = _aesDecrypt(bodyBytes);
      final decompressed = _decompress(decrypted);
      final jsonStr = utf8.decode(decompressed);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw TitleApiException('Response body is not valid JSON: $e');
    } on Exception catch (e) {
      throw TitleApiException('Failed to process response body: $e');
    }
  }

  String _buildHash(String apiName) {
    final raw = apiName + _obfuscateConstant + _config.obfuscateParam;
    return md5.convert(utf8.encode(raw)).toString();
  }

  Future<Map<String, dynamic>> _callApi(
    String apiName,
    Map<String, dynamic> packet,
    int userId,
  ) async {
    final hash = _buildHash(apiName);
    final body = _buildRequestBody(packet);
    final baseUrl = _normalizeUrl(_config.titleServerUrl);
    final url = Uri.parse('$baseUrl/$hash');

    // ignore: avoid_print
    print('══════════════════════════════════════');
    // ignore: avoid_print
    print('[$apiName] >>> REQUEST >>>');
    // ignore: avoid_print
    print('[$apiName] URL: $url');
    // ignore: avoid_print
    print('[$apiName] userId: $userId');
    // ignore: avoid_print
    print('[$apiName] hash: $hash');
    // ignore: avoid_print
    print('[$apiName] body (encrypted): ${body.length} bytes');
    // ignore: avoid_print
    final packetStr = const JsonEncoder.withIndent('  ').convert(packet);
    // ignore: avoid_print
    print('[$apiName] packet (plain):');
    // ignore: avoid_print
    print(packetStr);

    final headers = <String, String>{
      'User-Agent': '$hash#$userId',
      'Content-Type': 'application/json',
      'Mai-Encoding': _config.apiVersion,
      'Accept-Encoding': '',
      'Charset': 'UTF-8',
      'Content-Encoding': 'deflate',
      'Host': 'maimai-gm.wahlap.com:42081',
    };
    final cookies = _cookies;
    if (cookies != null) {
      headers['Cookie'] = cookies;
      // ignore: avoid_print
      print('[$apiName] Cookie: $cookies');
    }

    final response = await http
        .post(
          url,
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    _captureCookiesFromResponse(response, apiName);

    // ignore: avoid_print
    print('[$apiName] HTTP status: ${response.statusCode}');
    // ignore: avoid_print
    print('[$apiName] response bytes: ${response.bodyBytes.length}');

    if (response.statusCode != 200) {
      throw TitleApiException('$apiName returned ${response.statusCode}');
    }

    if (response.bodyBytes.isEmpty) {
      throw TitleApiException('$apiName returned empty body');
    }

    final json = _processResponseBody(response.bodyBytes);
    final raw = const JsonEncoder.withIndent('  ').convert(json);
    // ignore: avoid_print
    print('[$apiName] <<< RESPONSE <<<');
    // ignore: avoid_print
    print(raw);
    // ignore: avoid_print
    print('══════════════════════════════════════');

    return json;
  }

  static int calcRandom() {
    final rand = _RandomHelper();
    final max = 1037933;
    final num2 = (rand.nextInt(max - 1) + 1) * 2069 + 1024;
    var num3 = 0;
    var n = num2;
    for (var i = 0; i < 32; i++) {
      num3 <<= 1;
      num3 += n % 2;
      n >>= 1;
    }
    return num3;
  }

  String _normalizeUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<UserPreviewDataBean> getUserPreview({
    required int userId,
    required String token,
  }) async {
    // ignore: avoid_print
    print('[getUserPreview] ===== START =====');
    // ignore: avoid_print
    print('[getUserPreview] userId=$userId');
    // ignore: avoid_print
    print('[getUserPreview] token=$token');
    // ignore: avoid_print
    print('[getUserPreview] clientId=${_config.clientId}');
    // ignore: avoid_print
    print('[getUserPreview] titleServerUrl=${_config.titleServerUrl}');
    // ignore: avoid_print
    print('[getUserPreview] aesKey.len=${_config.aesKeyBytes.length} aesIv.len=${_config.aesIvBytes.length}');

    const apiName = 'GetUserPreviewApi';
    final hash = _buildHash(apiName);
    // ignore: avoid_print
    print('[getUserPreview] hash=$hash');

    final packet = {
      'userId': userId,
      'segaIdAuthKey': '',
      'token': token,
      'clientId': _config.clientId,
    };
    // ignore: avoid_print
    print('[getUserPreview] packet=${jsonEncode(packet)}');

    // ignore: avoid_print
    print('[getUserPreview] building request body (compress + encrypt)...');
    final body = _buildRequestBody(packet);
    // ignore: avoid_print
    print('[getUserPreview] body size=${body.length} bytes');

    final baseUrl = _normalizeUrl(_config.titleServerUrl);
    final url = Uri.parse('$baseUrl/$hash');
    // ignore: avoid_print
    print('[getUserPreview] POST $url');

    try {
      final previewHeaders = <String, String>{
        'User-Agent': '$hash#$userId',
        'Content-Type': 'application/json',
        'Mai-Encoding': _config.apiVersion,
        'Accept-Encoding': '',
        'Charset': 'UTF-8',
        'Content-Encoding': 'deflate',
        'Host': 'maimai-gm.wahlap.com:42081',
      };
      final previewCookies = _cookies;
      if (previewCookies != null) {
        previewHeaders['Cookie'] = previewCookies;
        // ignore: avoid_print
        print('[getUserPreview] Cookie: $previewCookies');
      }

      final response = await http
          .post(
            url,
            headers: previewHeaders,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      // ignore: avoid_print
      print('[getUserPreview] HTTP status=${response.statusCode}');
      // ignore: avoid_print
      print('[getUserPreview] response body size=${response.bodyBytes.length} bytes');

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('[getUserPreview] non-200 response body: ${utf8.decode(response.bodyBytes.take(500).toList())}');
        throw TitleApiException(
          'Server returned ${response.statusCode}',
        );
      }

      // ignore: avoid_print
      print('[getUserPreview] decrypting + decompressing...');
      final json = _processResponseBody(response.bodyBytes);
      final raw = const JsonEncoder.withIndent('  ').convert(json);
      lastRawResponse = raw;
      // ignore: avoid_print
      print('[getUserPreview] === RESPONSE ===');
      // ignore: avoid_print
      print(raw);
      // ignore: avoid_print
      print('[getUserPreview] ===== END =====');
      return UserPreviewDataBean.fromJson(json);
    } catch (e) {
      // ignore: avoid_print
      print('[getUserPreview] ERROR: $e');
      rethrow;
    }
  }

  // ---- Generic data APIs ----

  Future<Map<String, dynamic>> getUserData(int userId) async {
    return _callApi('GetUserDataApi', {'userId': userId}, userId);
  }

  Future<UserDataBean> getUserDataTyped(int userId) async {
    final json = await getUserData(userId);
    return UserDataBean.fromJson(json);
  }

  Future<Map<String, dynamic>> getUserExtend(int userId) async {
    return _callApi('GetUserExtendApi', {'userId': userId}, userId);
  }

  Future<Map<String, dynamic>> getUserOption(int userId) async {
    return _callApi('GetUserOptionApi', {'userId': userId}, userId);
  }

  Future<Map<String, dynamic>> getUserRating(int userId) async {
    return _callApi('GetUserRatingApi', {'userId': userId}, userId);
  }

  Future<Map<String, dynamic>> getUserCharge(int userId) async {
    return _callApi('GetUserChargeApi', {'userId': userId}, userId);
  }

  Future<Map<String, dynamic>> getUserActivity(int userId) async {
    return _callApi('GetUserActivityApi', {'userId': userId}, userId);
  }

  Future<Map<String, dynamic>> getUserMissionData(int userId) async {
    return _callApi('GetUserMissionDataApi', {'userId': userId}, userId);
  }

  // ---- UserLogin (returns full result) ----

  Future<UserLoginResult> userLoginFull({
    required int userId,
    required String token,
  }) async {
    const apiName = 'UserLoginApi';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final packet = {
      'userId': userId,
      'accessCode': '',
      'regionId': _config.regionId,
      'placeId': _config.placeId,
      'clientId': _config.clientId,
      'dateTime': now - 600,
      'loginDateTime': now,
      'isContinue': false,
      'genericFlag': 0,
      'token': token,
    };

    final json = await _callApi(apiName, packet, userId);

    final returnCode = json['returnCode'] as int? ?? -1;
    if (returnCode != 1) {
      throw TitleApiException('UserLoginApi returnCode=$returnCode');
    }

    final loginId = (json['loginId'] as num?)?.toInt() ?? 0;
    final lastLoginDate = json['lastLoginDate'] as String? ?? '';
    final newToken = json['token'] as String? ?? '';

    return UserLoginResult(
      token: newToken,
      loginId: loginId,
      lastLoginDate: lastLoginDate,
      loginDateTime: now,
    );
  }

  // ---- UserLogout ----

  Future<void> userLogout({
    required int userId,
    required int loginDateTime,
  }) async {
    const apiName = 'UserLogoutApi';

    final packet = {
      'userId': userId,
      'accessCode': '',
      'regionId': _config.regionId,
      'placeId': _config.placeId,
      'clientId': _config.clientId,
      'loginDateTime': loginDateTime,
      'type': 1, // LogoutType.Logout
    };

    final json = await _callApi(apiName, packet, userId);
    final returnCode = json['returnCode'] as int? ?? -1;
    if (returnCode != 1) {
      throw TitleApiException('UserLogoutApi returnCode=$returnCode');
    }
  }

  // ---- UpsertUserChargeLog (使用功能票) ----
  // Reference: KanadeBot SendTicketCommand / PayloadBuilder.generateTicketRequest

  static const _ticketPriceMap = {1: 1, 2: 6, 3: 2, 4: 2, 5: 2, 6: 0};

  Future<void> upsertUserChargeLog({
    required int userId,
    required int ticketId,
    required int loginDateTime,
    required int playerRating,
    int playCount = 0,
  }) async {
    const apiName = 'UpsertUserChargelogApi';
    final now = DateTime.now();
    final validDate = DateTime(now.year, now.month, now.day, 4, 0, 0)
        .add(const Duration(days: 90));
    final purchaseDateStr = _formatDateTime(now);
    final validDateStr =
        '${validDate.year}-${validDate.month.toString().padLeft(2, '0')}-${validDate.day.toString().padLeft(2, '0')} '
        '${validDate.hour.toString().padLeft(2, '0')}:${validDate.minute.toString().padLeft(2, '0')}:${validDate.second.toString().padLeft(2, '0')}';

    final packet = {
      'userId': userId,
      'userChargelog': {
        'chargeId': ticketId,
        'price': _ticketPriceMap[ticketId] ?? 0,
        'purchaseDate': purchaseDateStr,
        'playCount': playCount,
        'playerRating': playerRating,
        'placeId': _config.placeId,
        'regionId': _config.regionId,
        'clientId': _config.clientId,
      },
      'userCharge': {
        'chargeId': ticketId,
        'stock': 1,
        'purchaseDate': purchaseDateStr,
        'validDate': validDateStr,
      },
      'loginDateTime': loginDateTime,
    };

    final json = await _callApi(apiName, packet, userId);
    final returnCode = json['returnCode'] as int? ?? -1;
    if (returnCode != 1) {
      throw TitleApiException('UpsertUserChargelogApi returnCode=$returnCode');
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.0';
  }
}

class _RandomHelper {
  final _random = Random();

  int nextInt(int max) => _random.nextInt(max);
}

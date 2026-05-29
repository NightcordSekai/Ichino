import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TitleServerConfig {
  final String titleServerUrl;
  final String aesKey;
  final String aesIv;
  final String obfuscateParam;
  final String apiVersion;
  final String clientId;
  final int regionId;
  final int placeId;
  final String regionName;
  final String placeName;
  final String keychipId;
  final String aimeUrl;
  final String aimeSalt;
  final String openGameID;

  const TitleServerConfig({
    required this.titleServerUrl,
    required this.aesKey,
    required this.aesIv,
    this.obfuscateParam = '',
    this.apiVersion = '',
    required this.clientId,
    this.regionId = 0,
    this.placeId = 0,
    this.regionName = '',
    this.placeName = '',
    this.keychipId = '',
    this.aimeUrl = '',
    this.aimeSalt = '',
    String? openGameID,
  }) : openGameID = openGameID ?? '';

  List<int> get aesKeyBytes => utf8.encode(aesKey);
  List<int> get aesIvBytes => utf8.encode(aesIv);

  Map<String, dynamic> toJson() => {
        'titleServerUrl': titleServerUrl,
        'aesKey': aesKey,
        'aesIv': aesIv,
        'obfuscateParam': obfuscateParam,
        'apiVersion': apiVersion,
        'clientId': clientId,
        'regionId': regionId,
        'placeId': placeId,
        'regionName': regionName,
        'placeName': placeName,
        'keychipId': keychipId,
        'aimeUrl': aimeUrl,
        'aimeSalt': aimeSalt,
        'openGameID': openGameID,
      };

  factory TitleServerConfig.fromJson(Map<String, dynamic> json) {
    return TitleServerConfig(
      titleServerUrl: json['titleServerUrl'] as String? ?? '',
      aesKey: json['aesKey'] as String? ?? '',
      aesIv: json['aesIv'] as String? ?? '',
      obfuscateParam: json['obfuscateParam'] as String? ?? '',
      apiVersion: json['apiVersion'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      regionId: json['regionId'] as int? ?? 0,
      placeId: json['placeId'] as int? ?? 0,
      regionName: json['regionName'] as String? ?? '',
      placeName: json['placeName'] as String? ?? '',
      keychipId: json['keychipId'] as String? ?? '',
      aimeUrl: json['aimeUrl'] as String? ?? '',
      aimeSalt: json['aimeSalt'] as String? ?? '',
      openGameID: json['openGameID'] as String? ?? '',
    );
  }
}

class TitleServerConfigHolder {
  static const _storageKey = 'title_server_config';

  static final TitleServerConfigHolder _instance = TitleServerConfigHolder._();
  factory TitleServerConfigHolder() => _instance;
  TitleServerConfigHolder._();

  TitleServerConfig? _config;
  TitleServerConfig? get config => _config;

  bool get isConfigured {
    final c = _config;
    return c != null &&
        c.titleServerUrl.isNotEmpty &&
        c.aesKey.isNotEmpty &&
        c.aesIv.isNotEmpty &&
        c.clientId.isNotEmpty;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _config = TitleServerConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        _config = null;
      }
    }
  }

  Future<void> update(TitleServerConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(config.toJson()));
  }

  Future<void> clear() async {
    _config = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

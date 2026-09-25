import 'dart:convert';

import 'package:http/http.dart' as http;

import 'music_data_cache.dart';

class MusicInfo {
  final String title;
  final Map<int, double> dsByLevel;

  const MusicInfo({required this.title, required this.dsByLevel});
}

/// 乐曲元数据来源，移植自 Empurple 的 `MusicDataProvider`。
///
/// 游戏接口的 ratingList 只有 musicId，曲名与各难度定数需要另行获取。
class MusicDataService {
  static const String _musicDataUrl =
      'https://www.diving-fish.com/api/maimaidxprober/music_data';
  static const String _cacheFileName = 'music_data.json';

  MusicDataService._();

  static final MusicDataService instance = MusicDataService._();

  final Map<int, MusicInfo> _byId = {};
  Future<void>? _inFlight;

  String getTitle(int musicId) => _byId[musicId]?.title ?? 'Unknown';

  /// 缺失定数时返回 0，RA 也随之为 0，与 Empurple 行为一致。
  double getDs(int musicId, int level) =>
      _byId[musicId]?.dsByLevel[level] ?? 0.0;

  /// 并发调用共享同一次下载。
  Future<void> load() {
    if (_byId.isNotEmpty) return Future.value();
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    final cached = await readTextCache(_cacheFileName);
    final content = cached ?? await _download();
    _parse(content);
    if (cached == null) {
      await writeTextCache(_cacheFileName, content);
    }
  }

  Future<String> _download() async {
    final response = await http
        .get(Uri.parse(_musicDataUrl), headers: const {'User-Agent': 'Ichino/1.0'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('music_data HTTP ${response.statusCode}');
    }
    return response.body;
  }

  void _parse(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! List) return;
    _byId.clear();
    for (final item in decoded.whereType<Map<String, dynamic>>()) {
      final id = _toInt(item['id']);
      if (id == 0) continue;
      final ds = item['ds'];
      _byId[id] = MusicInfo(
        title: item['title']?.toString() ?? 'Unknown',
        dsByLevel: ds is List
            ? {
                for (var level = 0; level < ds.length; level++)
                  level: _toDouble(ds[level]),
              }
            : const {},
      );
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

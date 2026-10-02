import 'dart:convert';

import 'title_api_service.dart';

/// 一次账号备份的结果。
class AccountBackup {
  static const int formatVersion = 1;

  final Map<String, dynamic> document;

  /// 读失败的段名（含原因）。备份不因为单段失败而整体作废——
  /// 私服不一定实现了所有 GetUser* 接口。
  final List<String> failedSections;

  const AccountBackup({required this.document, required this.failedSections});

  /// 备份正文就是这一长串 JSON。
  String encode() => const JsonEncoder.withIndent('  ').convert(document);

  int get byteLength => utf8.encode(encode()).length;

  bool get isComplete => failedSections.isEmpty;
}

/// 把已经读到的各段数据拼成备份文档。与取数分开，方便单测。
Map<String, dynamic> buildBackupDocument({
  required int userId,
  required Map<String, Object?> sections,
  DateTime? exportedAt,
}) {
  return {
    'backupFormat': AccountBackup.formatVersion,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'userId': userId,
    'data': sections,
  };
}

/// 备份要读的道具类别，对应 `Net.VO.Mai2.ItemKind`。
///
/// 只列客户端下行真会读的那些：`StateUserDownload.cs:49-52` 逐个 kind 拉
/// `GetUserItemApi`，而 itemKind 15（KaleidxScopeKey）客户端从不读
/// （钥匙是 `userKaleidxScopeList[].isKeyFound`），所以不在此列。
const List<int> kBackupItemKinds = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12];

/// 读取用户数据并汇总成备份。
///
/// 每段独立容错：某私服没实现某个接口时，其余部分照样能备出来，
/// 失败原因记在 [AccountBackup.failedSections] 里给界面显示。
class AccountBackupService {
  final TitleApiService _api;
  final int userId;

  const AccountBackupService(this._api, {required this.userId});

  /// [onSection] 每开始读一段回调一次，供界面显示进度。
  Future<AccountBackup> run({void Function(String section)? onSection}) async {
    final sections = <String, Object?>{};
    final failed = <String>[];

    Future<void> gather(String name, Future<Object?> Function() read) async {
      onSection?.call(name);
      try {
        final value = await read();
        sections[name] = value;
      } catch (e) {
        failed.add('$name: $e');
      }
    }

    // 单段一个请求：并发跑，且一段失败不牵连其他段。
    await Future.wait([
      gather('userData', () => _api.getUserData(userId)),
      gather('userExtend', () => _api.getUserExtend(userId)),
      gather('userOption', () => _api.getUserOption(userId)),
      gather('userRating', () => _api.getUserRating(userId)),
      gather('userCharge', () => _api.getUserCharge(userId)),
      gather('userActivity', () => _api.getUserActivity(userId)),
      gather('userMissionData', () => _api.getUserMissionData(userId)),
      gather(
        'userCharacterList',
        () async => [
          for (final c in await _api.getUserCharacters(userId)) c.toWireJson(),
        ],
      ),
      gather('userMapList', () => _api.getUserMaps(userId)),
      gather(
        'userKaleidxScopeList',
        () async => [
          for (final s in await _api.getUserKaleidxScopes(userId))
            s.toWireJson(),
        ],
      ),
    ]);

    // userItemList 是按 itemKind 分页拉的，按 kind 分组存放，
    // 读回时一眼能看出哪类是空的、哪类根本没读到。
    final items = <String, Object?>{};
    await Future.wait([
      for (final kind in kBackupItemKinds)
        () async {
          onSection?.call('itemKind $kind');
          try {
            items['$kind'] = await _api.getUserItems(userId, kind);
          } catch (e) {
            failed.add('userItemList/$kind: $e');
          }
        }(),
    ]);
    sections['userItemList'] = items;

    return AccountBackup(
      document: buildBackupDocument(userId: userId, sections: sections),
      failedSections: failed,
    );
  }
}

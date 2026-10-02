import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/services/account_backup_service.dart';

void main() {
  group('账号备份文档', () {
    final sections = <String, Object?>{
      'userData': {
        'userData': {'point': 123456, 'totalPoint': 999999, 'playCount': 1234},
      },
      'userCharacterList': [
        {'characterId': 101, 'level': 999999, 'awakening': 0, 'useCount': 7},
      ],
      'userMapList': [
        {'mapId': 550002, 'distance': 999999999, 'isComplete': true},
      ],
      'userItemList': {
        '5': [
          {'itemKind': 5, 'itemId': 11820, 'stock': 1, 'isValid': true},
        ],
        '6': const <Object?>[],
      },
    };

    test('带格式版本、userId 与 exportedAt，各段挂在 data 下', () {
      final doc = buildBackupDocument(
        userId: 42,
        sections: sections,
        exportedAt: DateTime.utc(2026, 10, 2, 3, 4, 5),
      );

      expect(doc['backupFormat'], AccountBackup.formatVersion);
      expect(doc['userId'], 42);
      expect(doc['exportedAt'], '2026-10-02T03:04:05.000Z');
      expect(doc['data'], sections);
    });

    test('encode 出来的是能原样解回来的 JSON 字符串', () {
      final backup = AccountBackup(
        document: buildBackupDocument(userId: 42, sections: sections),
        failedSections: const [],
      );

      final text = backup.encode();
      expect(text, isA<String>());
      expect(text.contains('11820'), isTrue);

      final back = jsonDecode(text) as Map<String, dynamic>;
      final data = back['data'] as Map<String, dynamic>;
      final userData =
          (data['userData'] as Map<String, dynamic>)['userData']
              as Map<String, dynamic>;
      expect(userData['point'], 123456);

      final items = data['userItemList'] as Map<String, dynamic>;
      expect(items['5'], hasLength(1));
      // 空的那一类要留着：「读到但是空的」和「没读到」不是一回事。
      expect(items.containsKey('6'), isTrue);
      expect(items['6'], isEmpty);
    });

    test('单段失败不算整体失败，但会记下来并让 isComplete 变 false', () {
      final backup = AccountBackup(
        document: buildBackupDocument(userId: 7, sections: sections),
        failedSections: const ['userMaps: HTTP 500', 'userItemList/12: 超时'],
      );

      expect(backup.isComplete, isFalse);
      expect(backup.failedSections, hasLength(2));
      // 失败信息不进 data，备份正文仍然可用。
      expect(
        (jsonDecode(backup.encode()) as Map)['data'].containsKey('userMaps'),
        isFalse,
      );
    });

    test('byteLength 与实际编码长度一致', () {
      final backup = AccountBackup(
        document: buildBackupDocument(userId: 7, sections: sections),
        failedSections: const [],
      );

      expect(backup.byteLength, utf8.encode(backup.encode()).length);
    });

    test('备份要覆盖用户点名的那几类数据', () {
      expect(kBackupItemKinds, containsAll([1, 2, 3, 5, 6, 7, 10, 11, 12]));
      // 15 = KaleidxScopeKey，客户端从不读它，不该出现在回读清单里。
      expect(kBackupItemKinds, isNot(contains(15)));
    });
  });
}

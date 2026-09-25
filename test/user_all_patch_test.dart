import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/models/user_character.dart';
import 'package:ichino/services/user_all_payload_builder.dart';

const _config = TitleServerConfig(
  titleServerUrl: 'http://127.0.0.1:9999',
  aesKey: '0123456789abcdef',
  aesIv: '0123456789abcdef',
  clientId: 'A63E01C2805',
);

Map<String, dynamic> _buildPacket(UserAllPayloadBuilder builder) =>
    builder.build(
      userId: 42,
      loginId: 7,
      loginDateTime: 1700000000,
      musicData: const {
        'musicId': 11538,
        'level': 0,
        'playCount': 1,
        'achievement': 0,
        'comboStatus': 0,
        'syncStatus': 0,
        'deluxscoreMax': 0,
        'scoreRank': 0,
        'extNum1': 0,
      },
      generalUserInfo: const {},
    );

Map<String, dynamic> _upsert(Map<String, dynamic> packet) =>
    packet['upsertUserAll'] as Map<String, dynamic>;

void main() {
  group('旅行伙伴 userCharacterList patch', () {
    test('写入 4 字段行并按行数生成 isNewCharacterList', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyCharacterListPatch(packet, characters: [
        {'characterId': 1001, 'level': 1, 'awakening': 0, 'useCount': 0},
        {'characterId': 1002, 'level': 3, 'awakening': 1, 'useCount': 9},
      ]);

      final upsert = _upsert(packet);
      expect(upsert['userCharacterList'], hasLength(2));
      expect(upsert['isNewCharacterList'], '11');
      final first = (upsert['userCharacterList'] as List).first
          as Map<String, dynamic>;
      // 客户端 UserCharacter 结构只有这 4 个字段，多一个都可能被拒。
      expect(first.keys.toSet(), {
        'characterId',
        'level',
        'awakening',
        'useCount',
      });
    });

    test('空列表时 isNewCharacterList 为空串', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);
      builder.applyCharacterListPatch(packet, characters: []);
      expect(_upsert(packet)['isNewCharacterList'], '');
    });
  });

  group('charaSlot 编组 patch', () {
    test('槽位补齐到 5 并同步 playlog 的 characterId1..5', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyCharaSlotPatch(packet, charaSlot: const [1001]);

      final userData = (_upsert(packet)['userData'] as List).first
          as Map<String, dynamic>;
      expect(userData['charaSlot'], [1001, 0, 0, 0, 0]);

      final playlog = (packet['userPlaylogList'] as List).first
          as Map<String, dynamic>;
      expect(playlog['characterId1'], 1001);
      expect(playlog['characterId2'], 0);
    });

    test('超过 5 个槽位被截断', () {
      expect(
        normalizeCharaSlot(const [1, 2, 3, 4, 5, 6, 7]),
        [1, 2, 3, 4, 5],
      );
    });

    test('一键复制槽 0 到其余槽位', () {
      final slots = normalizeCharaSlot(const [1001, 0, 0, 0, 0]);
      final copied = normalizeCharaSlot([
        for (var i = 0; i < 5; i++) slots[0],
      ]);
      expect(copied, [1001, 1001, 1001, 1001, 1001]);
    });
  });

  group('收藏品 userItemList patch', () {
    test('多行道具与 isNewItemList 位数一致', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyItemListPatch(packet, items: [
        {'itemKind': 9, 'itemId': 1001, 'stock': 1, 'isValid': true},
        {'itemKind': 10, 'itemId': 2002, 'stock': 1, 'isValid': true},
      ]);

      final upsert = _upsert(packet);
      expect(upsert['userItemList'], hasLength(2));
      expect(upsert['isNewItemList'], '11');
    });
  });
}

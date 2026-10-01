import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/models/user_character.dart';
import 'package:ichino/models/user_kaleidx_scope.dart';
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

  group('总 Rating patch', () {
    test('只改 playerRating 与 userRating.rating，每首歌的 ratingList 不动', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = builder.build(
        userId: 42,
        loginId: 7,
        loginDateTime: 1700000000,
        musicData: const {'musicId': 11538, 'level': 0, 'achievement': 0},
        generalUserInfo: const {
          'GetUserDataApi': {
            'userData': {
              'playerRating': 12345,
              'highestRating': 13000,
              'gradeRating': 5000,
              'charaSlot': [101],
            },
          },
          'GetUserRatingApi': {
            'userRating': {
              'rating': 12345,
              'ratingList': [
                {'musicId': 834, 'level': 4, 'rating': 100},
              ],
              'newRatingList': [
                {'musicId': 11538, 'level': 3, 'rating': 200},
              ],
            },
          },
        },
      );

      builder.applyRatingPatch(packet, rating: 99999);

      final upsert = _upsert(packet);
      final userData = (upsert['userData'] as List).first
          as Map<String, dynamic>;
      final userRating = (upsert['userRatingList'] as List).first
          as Map<String, dynamic>;
      expect(userData['playerRating'], 99999);
      expect(userRating['rating'], 99999);

      // 每首歌各自的 Rating 必须原样带回。
      expect(userRating['ratingList'], [
        {'musicId': 834, 'level': 4, 'rating': 100},
      ]);
      expect(userRating['newRatingList'], [
        {'musicId': 11538, 'level': 3, 'rating': 200},
      ]);
      // 历史最高、段位 Rating 这些不属于「总 Rating」。
      expect(userData['highestRating'], 13000);
      expect(userData['gradeRating'], 5000);

      final playlog = (packet['userPlaylogList'] as List).first
          as Map<String, dynamic>;
      expect(playlog['beforeRating'], 12345);
      expect(playlog['afterRating'], 99999);
      expect(playlog['beforeDeluxRating'], 12345);
      expect(playlog['afterDeluxRating'], 99999);
    });

    test('Rating 超过 99999 被钳到上限，负数钳到 0', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyRatingPatch(
        packet,
        rating: UserAllPayloadBuilder.maxRating + 500,
      );

      final userData =
          ((_upsert(packet))['userData'] as List).first as Map<String, dynamic>;
      expect(userData['playerRating'], UserAllPayloadBuilder.maxRating);

      builder.applyRatingPatch(packet, rating: -5);
      final clamped = (_upsert(packet)['userData'] as List).first
          as Map<String, dynamic>;
      expect(clamped['playerRating'], 0);
    });

    test('GetUserRatingApi 缺数据时不会写到 const 空 map 上崩掉', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      expect(() => builder.applyRatingPatch(packet, rating: 5000), returnsNormally);
      final userRating = (_upsert(packet))['userRatingList'] as List;
      expect(userRating.first, {'rating': 5000});
    });
  });

  group('舞里程 patch', () {
    test('point 与 totalPoint 分别写入，totalPoint 省略时保持原值', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = builder.build(
        userId: 42,
        loginId: 7,
        loginDateTime: 1700000000,
        musicData: const {'musicId': 11538, 'level': 0, 'achievement': 0},
        generalUserInfo: const {
          'GetUserDataApi': {
            'userData': {'point': 8000, 'totalPoint': 120000},
          },
        },
      );

      builder.applyMaiMilePatch(packet, point: 99999);

      final userData =
          (_upsert(packet))['userData'] as List;
      final row = userData.first as Map<String, dynamic>;
      expect(row['point'], 99999);
      expect(row['totalPoint'], 120000);
    });

    test('累加越过 int32 上界时被钳住', () {
      const current = 2147483000;
      final builder = UserAllPayloadBuilder(_config);
      final packet = builder.build(
        userId: 42,
        loginId: 7,
        loginDateTime: 1700000000,
        musicData: const {'musicId': 11538, 'level': 0, 'achievement': 0},
        generalUserInfo: const {
          'GetUserDataApi': {
            'userData': {'point': current, 'totalPoint': current},
          },
        },
      );

      // 累加 2000 会越过 int32 上界，应被钳住。
      builder.applyMaiMilePatch(
        packet,
        point: UserAllPayloadBuilder.clampValue(current + 2000),
        totalPoint: UserAllPayloadBuilder.clampValue(current + 2000),
      );

      final row = ((_upsert(packet))['userData'] as List).first
          as Map<String, dynamic>;
      expect(row['point'], UserAllPayloadBuilder.maxValue);
      expect(row['totalPoint'], UserAllPayloadBuilder.maxValue);
      expect(UserAllPayloadBuilder.maxValue, 2147483647);
      expect(UserAllPayloadBuilder.minValue, -2147483648);
    });

    test('负数舞里程原样写入，只有越过 int32 下界才钳', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = builder.build(
        userId: 42,
        loginId: 7,
        loginDateTime: 1700000000,
        musicData: const {'musicId': 11538, 'level': 0, 'achievement': 0},
        generalUserInfo: const {
          'GetUserDataApi': {
            'userData': {'point': 5000, 'totalPoint': 5000},
          },
        },
      );

      // 累加模式下填负数就是扣里程，不该被当成非法值抬回 0。
      builder.applyMaiMilePatch(packet, point: -7);

      final row = (_upsert(packet)['userData'] as List).first
          as Map<String, dynamic>;
      expect(row['point'], -7);
    });

    test('clampValue 的两侧边界', () {
      expect(UserAllPayloadBuilder.clampValue(0), 0);
      expect(UserAllPayloadBuilder.clampValue(-7), -7);
      expect(
        UserAllPayloadBuilder.clampValue(UserAllPayloadBuilder.maxValue + 1),
        UserAllPayloadBuilder.maxValue,
      );
      expect(
        UserAllPayloadBuilder.clampValue(UserAllPayloadBuilder.minValue - 1),
        UserAllPayloadBuilder.minValue,
      );
    });
  });

  group('旅行伙伴等级 patch', () {
    test('新增行标 1、改等级行标 0，两段拼成 isNewCharacterList', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyCharacterListPatch(
        packet,
        characters: [
          {'characterId': 101, 'level': 999999, 'awakening': 0, 'useCount': 0},
          {'characterId': 102, 'level': 5000, 'awakening': 3, 'useCount': 77},
        ],
        newFlags: '10',
      );

      final upsert = _upsert(packet);
      expect(upsert['isNewCharacterList'], '10');
      expect(upsert['userCharacterList'], hasLength(2));
    });

    test('省略 newFlags 时沿用全 1 的新增语义', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyCharacterListPatch(packet, characters: [
        {'characterId': 101, 'level': 1, 'awakening': 0, 'useCount': 0},
      ]);

      expect(_upsert(packet)['isNewCharacterList'], '1');
    });

    test('等级钳位：0 以下抬到 1，超过真实等级上限压到 999999', () {
      expect(UserAllPayloadBuilder.clampCharacterLevel(0), 1);
      expect(UserAllPayloadBuilder.clampCharacterLevel(-9), 1);
      expect(UserAllPayloadBuilder.clampCharacterLevel(10000000), 999999);
      expect(UserAllPayloadBuilder.clampCharacterLevel(999999), 999999);
    });
  });

  group('一键跑图 userMapList patch', () {
    test('完成行的字段与 Net.VO.Mai2.UserMap 一一对应', () {
      final row = UserAllPayloadBuilder.completedMap(550001);

      // unlockFlag 语义是反的：0 才表示已开启（IsFinishedOpening）。
      expect(row.keys.toSet(), {
        'mapId',
        'distance',
        'isLock',
        'isClear',
        'isComplete',
        'unlockFlag',
      });
      expect(row['mapId'], 550001);
      expect(row['isClear'], isTrue);
      expect(row['isComplete'], isTrue);
      expect(row['unlockFlag'], 0);
      // distance 必须推过 End 针，否则客户端会用 distance 把 flag 冲回 false。
      expect(row['distance'], UserAllPayloadBuilder.maxMapDistance);
    });

    test('isNewMapList 每位对应一行，服务器已有的行标 0', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      builder.applyMapPatch(
        packet,
        maps: [
          UserAllPayloadBuilder.completedMap(1),
          UserAllPayloadBuilder.completedMap(2),
          UserAllPayloadBuilder.completedMap(3),
        ],
        newFlags: '010',
      );

      final upsert = _upsert(packet);
      expect(upsert['userMapList'], hasLength(3));
      expect(upsert['isNewMapList'], '010');
      expect(upsert['isNewMapList'].length,
          (upsert['userMapList'] as List).length);
    });

    test('可以单独抬高 distance 而不动其它字段', () {
      final row = UserAllPayloadBuilder.completedMap(9, distance: 12345);
      expect(row['distance'], 12345);
    });
  });

  group('万花筒 userKaleidxScopeList patch', () {
    test('wire 行的 15 个字段与 UserKaleidxScope 结构一致', () {
      final row = const UserKaleidxScopeBean(gateId: 3).toWireJson();

      // totalDeluxscore 的拼写是原样的 Deluxscore，写错服务器认不出。
      expect(row.keys.toList(), [
        'gateId',
        'isGateFound',
        'isKeyFound',
        'isClear',
        'totalRestLife',
        'totalAchievement',
        'totalDeluxscore',
        'bestAchievement',
        'bestDeluxscore',
        'bestAchievementDate',
        'bestDeluxscoreDate',
        'playCount',
        'clearDate',
        'lastPlayDate',
        'isInfoWatched',
      ]);
      // 日期字段用 "" 而不是 null，对齐客户端 class 构造器的默认值。
      expect(row['bestAchievementDate'], '');
      expect(row['clearDate'], '');
    });

    test('isNewKaleidxScopeList 位数与行数一致，已有行标 0', () {
      final builder = UserAllPayloadBuilder(_config);
      final packet = _buildPacket(builder);

      final scopes = [
        const UserKaleidxScopeBean(gateId: 1, isGateFound: true),
        const UserKaleidxScopeBean(gateId: 2, isGateFound: true),
      ];
      builder.applyKaleidxScopePatch(
        packet,
        scopes: [for (final s in scopes) s.toWireJson()],
        newFlags: '01',
      );

      final upsert = _upsert(packet);
      expect(upsert['userKaleidxScopeList'], hasLength(2));
      expect(upsert['isNewKaleidxScopeList'], '01');
      expect(
        (upsert['isNewKaleidxScopeList'] as String).length,
        (upsert['userKaleidxScopeList'] as List).length,
      );
    });

    test('新发现门：isGateFound=true，给钥匙时连带把门标为已发现', () {
      final foundOnly = UserKaleidxScopeBean.discovered(
        7,
        giveKey: false,
      ).toWireJson();
      expect(foundOnly['isGateFound'], isTrue);
      expect(foundOnly['isKeyFound'], isFalse);

      final withKey = UserKaleidxScopeBean.discovered(
        7,
        giveKey: true,
      ).toWireJson();
      expect(withKey['isKeyFound'], isTrue);
      expect(withKey['isGateFound'], isTrue);
    });

    test('已有行只叠加布尔位，成绩与日期不被清零', () {
      final server = UserKaleidxScopeBean.fromJson(const {
        'gateId': 4,
        'isGateFound': true,
        'isKeyFound': false,
        'isClear': false,
        'totalRestLife': 5,
        'totalAchievement': 612345,
        'totalDeluxscore': 987,
        'bestAchievement': 1012345,
        'bestDeluxscore': 55,
        'bestAchievementDate': '2026-01-02 03:04:05.0',
        'bestDeluxscoreDate': '2026-01-02 03:04:05.0',
        'playCount': 12,
        'clearDate': '',
        'lastPlayDate': '2026-09-01 00:00:00.0',
        'isInfoWatched': true,
      });

      final updated = server
          .withActions(discover: false, giveKey: true)
          .toWireJson();

      expect(updated['isKeyFound'], isTrue);
      expect(updated['isGateFound'], isTrue);
      expect(updated['bestAchievement'], 1012345);
      expect(updated['bestAchievementDate'], '2026-01-02 03:04:05.0');
      expect(updated['playCount'], 12);
      expect(updated['totalRestLife'], 5);
      expect(updated['isInfoWatched'], isTrue);
      expect(updated['lastPlayDate'], '2026-09-01 00:00:00.0');
    });

    test('withActions 不会把已经为 true 的位改回 false', () {
      const cleared = UserKaleidxScopeBean(
        gateId: 9,
        isGateFound: true,
        isKeyFound: true,
        isClear: true,
      );

      final again = cleared.withActions(discover: true, giveKey: false);

      expect(again.isGateFound, isTrue);
      expect(again.isKeyFound, isTrue);
      expect(again.isClear, isTrue);
    });

    test('状态文案覆盖四种组合，隐形态单独说明', () {
      expect(AppStrings.kaleidxGateState(false, false, false), '未见过');
      expect(AppStrings.kaleidxGateState(true, false, false), '已发现 · 未解锁');
      expect(AppStrings.kaleidxGateState(true, true, false), '可挑战');
      expect(AppStrings.kaleidxGateState(true, true, true), '已通关');
      // !found && key 是隐形，不是「锁着的门」。
      expect(
        AppStrings.kaleidxGateState(false, true, false),
        contains('隐形'),
      );
    });

    test('标记通关时落一个首次通关日期，已有日期不被覆盖', () {
      const noDate = UserKaleidxScopeBean(gateId: 5);
      final marked = noDate.withActions(
        discover: true,
        giveKey: true,
        clear: true,
        timestamp: '2026-10-01 12:00:00.0',
      );
      expect(marked.isClear, isTrue);
      expect(marked.clearDate, '2026-10-01 12:00:00.0');

      const already = UserKaleidxScopeBean(
        gateId: 5,
        isGateFound: true,
        isKeyFound: true,
        isClear: true,
        clearDate: '2026-01-01 00:00:00.0',
      );
      final reMarked = already.withActions(
        discover: false,
        giveKey: false,
        clear: true,
        timestamp: '2026-10-01 12:00:00.0',
      );
      // clearDate 是「首次」通关日期，不能被后来的一次操作改掉。
      expect(reMarked.clearDate, '2026-01-01 00:00:00.0');
    });

    test('撤销通关把 clearDate 一起清掉', () {
      const cleared = UserKaleidxScopeBean(
        gateId: 6,
        isGateFound: true,
        isKeyFound: true,
        isClear: true,
        clearDate: '2026-01-01 00:00:00.0',
        playCount: 3,
      );

      final undone = cleared.withActions(
        discover: false,
        giveKey: false,
        clear: false,
      );

      expect(undone.isClear, isFalse);
      expect(undone.clearDate, '');
      // 只动通关态，成绩与次数要原样留着。
      expect(undone.playCount, 3);
      expect(undone.isKeyFound, isTrue);
    });

    test('通关状态选「不改动」时 null 不覆写原值', () {
      const cleared = UserKaleidxScopeBean(
        gateId: 8,
        isGateFound: true,
        isKeyFound: true,
        isClear: true,
        clearDate: '2026-01-01 00:00:00.0',
      );

      final kept = cleared.withActions(discover: true, giveKey: false);

      expect(kept.isClear, isTrue);
      expect(kept.clearDate, '2026-01-01 00:00:00.0');
    });

    test('新行也能直接建成已通关', () {
      final row = UserKaleidxScopeBean.discovered(
        11,
        giveKey: true,
        clear: true,
        timestamp: '2026-10-01 12:00:00.0',
      ).toWireJson();

      expect(row['isGateFound'], isTrue);
      expect(row['isKeyFound'], isTrue);
      expect(row['isClear'], isTrue);
      expect(row['clearDate'], '2026-10-01 12:00:00.0');
    });

    test('新行不选通关时 clearDate 留空', () {
      final row = UserKaleidxScopeBean.discovered(
        11,
        giveKey: false,
        clear: false,
        timestamp: '2026-10-01 12:00:00.0',
      ).toWireJson();

      expect(row['isClear'], isFalse);
      expect(row['clearDate'], '');
    });
  });
}

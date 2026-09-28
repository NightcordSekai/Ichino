import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/models/session_model.dart';
import 'package:ichino/models/session_share.dart';
import 'package:ichino/widgets/connection_share_card.dart';

void main() {
  group('SessionShare', () {
    test('编码后能解回同样的会话', () {
      const share = SessionShare(
        userId: 1234567,
        token: 'SGWCMAIDABCDEF',
        cookie: 'JSESSIONID=abc123DEF',
      );

      final decoded = SessionShare.tryDecode(share.encode());

      expect(decoded, isNotNull);
      expect(decoded!.userId, 1234567);
      expect(decoded.token, 'SGWCMAIDABCDEF');
      expect(decoded.jsessionid, 'JSESSIONID=abc123DEF');
    });

    test('只保留 JSESSIONID，忽略其它 Cookie', () {
      const share = SessionShare(
        userId: 1,
        token: 't',
        cookie: 'OTHER=x; JSESSIONID=keep-me; Path=/',
      );

      final decoded = SessionShare.tryDecode(share.encode())!;

      expect(decoded.jsessionid, 'JSESSIONID=keep-me');
    });

    test('换行与空白不影响解析', () {
      const share = SessionShare(
        userId: 42,
        token: 'tok',
        cookie: 'JSESSIONID=z',
      );
      final wrapped =
          '  ${share.encode().replaceAllMapped(RegExp(r'.{8}'), (m) => '${m[0]}\n')} ';

      expect(SessionShare.tryDecode(wrapped)?.userId, 42);
    });

    test('QR 令牌与乱码不是连接信息', () {
      final qrToken = 'SGWCMAID${'0123456789ABCDEF' * 3}01234567';
      expect(qrToken.length, 64);
      expect(SessionShare.tryDecode(qrToken), isNull);
      expect(SessionShare.tryDecode('not base64 at all !!'), isNull);
      expect(SessionShare.tryDecode(''), isNull);
    });

    test('cookie 与 token 都空、或 userId 非法时拒绝', () {
      expect(
        SessionShare.tryDecode(
          const SessionShare(
            userId: 0,
            token: '',
            cookie: 'JSESSIONID=x',
          ).encode(),
        ),
        isNull,
      );
      expect(
        SessionShare.tryDecode(
          const SessionShare(userId: 7, token: '', cookie: null).encode(),
        ),
        isNull,
      );
    });
  });

  group('ConnectionShareCard', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('复制到剪贴板并展开 Base64 内容与外传警示', (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add(((call.arguments as Map)['text'] as String?) ?? '');
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        wrap(const ConnectionShareCard(userId: 7, token: 'tok')),
      );

      expect(find.text(AppStrings.experimentalBadge), findsOneWidget);
      expect(find.text(AppStrings.connectionShareSecurity), findsNothing);

      await tester.tap(find.text(AppStrings.connectionShareCopy));
      await tester.pump();

      final encoded = SessionModel.instance
          .exportConnectionInfo(userId: 7, token: 'tok')
          .encode();
      expect(copied, [encoded]);
      expect(find.text(AppStrings.connectionShareSecurity), findsOneWidget);
      expect(find.text(encoded), findsOneWidget);
    });
  });
}

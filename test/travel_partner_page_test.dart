import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/pages/travel_partner_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPage(WidgetTester tester, {required bool loggedIn}) async {
  SharedPreferences.setMockInitialValues({});
  await TitleServerConfigHolder().update(
    const TitleServerConfig(
      titleServerUrl: 'http://127.0.0.1:9999',
      aesKey: '0123456789abcdef',
      aesIv: '0123456789abcdef',
      clientId: 'A63E01C2805',
    ),
  );

  tester.view.physicalSize = loggedIn ? const Size(420, 1500) : const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: TravelPartnerPage(
        userId: 42,
        cookies: 'JSESSIONID=X',
        loginDateTime: loggedIn ? 1 : null,
        loginId: loggedIn ? 7 : null,
        onExitToTitle: () async {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('已登录时渲染 5 个槽位与一键复制，且无溢出', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    expect(tester.takeException(), isNull);
    for (var i = 0; i < 5; i++) {
      expect(
        find.text(AppStrings.travelPartnerSlotLabel(i)),
        findsOneWidget,
        reason: '缺少槽位 $i 的下拉框',
      );
    }
    expect(find.text(AppStrings.travelPartnerCopySlot0), findsOneWidget);
    expect(find.text(AppStrings.travelPartnerGrantTitle), findsOneWidget);
  });

  testWidgets('未登录时给出提示并禁用执行', (tester) async {
    await _pumpPage(tester, loggedIn: false);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.travelPartnerNotLoggedIn), findsOneWidget);

    final run = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(AppStrings.travelPartnerRun),
        matching: find.byType(FilledButton),
      ),
    );
    expect(run.onPressed, isNull);
  });

  testWidgets('槽 0 未选择时复制按钮不改动槽位', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.tap(find.text(AppStrings.travelPartnerCopySlot0));
    await tester.pump();

    // 未拥有任何角色时，复制应被拦下并提示，而不是写入非法槽位。
    expect(find.text(AppStrings.travelPartnerCopyNeedSlot0), findsOneWidget);
  });
}

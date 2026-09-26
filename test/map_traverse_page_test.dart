import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/pages/map_traverse_page.dart';
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

  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MapTraversePage(
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

Finder _runFinder(WidgetTester tester) => find.ancestor(
  of: find.text(AppStrings.mapRun),
  matching: find.byType(FilledButton),
);

void main() {
  testWidgets('渲染区域 ID 输入与收藏品限制说明，且无溢出', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.mapIdLabel), findsOneWidget);
    expect(find.text(AppStrings.mapCollectiblesNotice), findsOneWidget);
    expect(find.text(AppStrings.mapNoData), findsOneWidget);
  });

  testWidgets('添加区域 ID 后进入待处理列表，重复添加被拒', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.enterText(find.byType(TextField), '550001');
    await tester.tap(find.text(AppStrings.listAddButton));
    await tester.pump();

    expect(find.text('#550001'), findsOneWidget);
    expect(find.text(AppStrings.mapNeedMapId), findsNothing);

    await tester.enterText(find.byType(TextField), '550001');
    await tester.tap(find.text(AppStrings.listAddButton));
    await tester.pump();

    expect(find.text(AppStrings.listDuplicate), findsOneWidget);
    expect(find.text('#550001'), findsOneWidget);
  });

  testWidgets('列表为空时执行被拦下', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.tap(_runFinder(tester));
    await tester.pump();

    expect(find.text(AppStrings.mapNeedMapId), findsOneWidget);
  });

  testWidgets('未登录时禁用执行', (tester) async {
    await _pumpPage(tester, loggedIn: false);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.mapNotLoggedIn), findsOneWidget);

    final run = tester.widget<FilledButton>(_runFinder(tester));
    expect(run.onPressed, isNull);
  });
}

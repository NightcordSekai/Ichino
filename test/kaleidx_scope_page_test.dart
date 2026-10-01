import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/pages/kaleidx_scope_page.dart';
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

  tester.view.physicalSize = const Size(420, 1700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: KaleidxScopePage(
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
  of: find.text(AppStrings.kaleidxRun),
  matching: find.byType(FilledButton),
);

void main() {
  testWidgets('渲染门 ID 输入、两个勾选与通关下拉，且无溢出', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.kaleidxGateIdLabel), findsOneWidget);
    expect(find.text(AppStrings.kaleidxActionDiscover), findsOneWidget);
    expect(find.text(AppStrings.kaleidxActionKey), findsOneWidget);
    // 没勾钥匙时不占版面。
    expect(find.text(AppStrings.kaleidxKeyNeedsGate), findsNothing);
  });

  testWidgets('勾了钥匙才解释「钥匙离不开门」', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.tap(find.text(AppStrings.kaleidxActionKey));
    await tester.pump();

    expect(find.text(AppStrings.kaleidxKeyNeedsGate), findsOneWidget);
  });

  testWidgets('添加门 ID 后出现在列表并带状态', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text(AppStrings.listAddButton));
    await tester.pump();

    expect(find.textContaining('#3'), findsOneWidget);
    expect(find.text(AppStrings.kaleidxPendingEmpty), findsNothing);
  });

  testWidgets('三个动作都不选时被拦下', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text(AppStrings.listAddButton));
    await tester.pump();

    await tester.tap(find.text(AppStrings.kaleidxActionDiscover));
    await tester.pump();
    await tester.tap(_runFinder(tester));
    await tester.pump();

    expect(find.text(AppStrings.kaleidxNeedAction), findsOneWidget);
  });

  testWidgets('通关状态下拉默认「不改动」，选已通关才提示需要钥匙', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    expect(find.text(AppStrings.kaleidxClearKeep), findsOneWidget);
    expect(find.text(AppStrings.kaleidxClearNeedsKey), findsNothing);

    await tester.tap(find.text(AppStrings.kaleidxClearKeep));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.kaleidxClearCleared).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.kaleidxClearCleared), findsOneWidget);
    expect(find.text(AppStrings.kaleidxClearNeedsKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('勾了钥匙时优先解释「钥匙离不开门」', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.tap(find.text(AppStrings.kaleidxActionKey));
    await tester.pump();
    await tester.tap(find.text(AppStrings.kaleidxClearKeep));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.kaleidxClearCleared).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.kaleidxKeyNeedsGate), findsOneWidget);
    // 两条提示不叠着刷屏。
    expect(find.text(AppStrings.kaleidxClearNeedsKey), findsNothing);
  });

  testWidgets('列表为空时执行被拦下', (tester) async {
    await _pumpPage(tester, loggedIn: true);

    await tester.tap(_runFinder(tester));
    await tester.pump();

    expect(find.text(AppStrings.kaleidxNeedGateId), findsOneWidget);
  });

  testWidgets('未登录时禁用执行', (tester) async {
    await _pumpPage(tester, loggedIn: false);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.kaleidxNotLoggedIn), findsOneWidget);

    final run = tester.widget<FilledButton>(_runFinder(tester));
    expect(run.onPressed, isNull);
  });
}

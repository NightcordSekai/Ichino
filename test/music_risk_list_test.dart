import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/pages/music_risk_feature_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _seedConfig() async {
  SharedPreferences.setMockInitialValues({});
  await TitleServerConfigHolder().update(
    const TitleServerConfig(
      titleServerUrl: 'http://127.0.0.1:9999',
      aesKey: '0123456789abcdef',
      aesIv: '0123456789abcdef',
      clientId: 'A63E01C2805',
    ),
  );
}

Future<void> _pumpView(WidgetTester tester, MusicRiskFeatureMode mode) async {
  await _seedConfig();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MusicRiskFeatureView(
          userId: 123,
          cookies: 'JSESSIONID=X',
          loginDateTime: 1,
          loginId: 2,
          mode: mode,
          featureTitle: 't',
          featureDesc: 'd',
          onExitToTitle: () async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _addById(WidgetTester tester, String label, String id) async {
  await tester.enterText(find.widgetWithText(TextField, label), id);
  await tester.tap(find.text(AppStrings.listAddButton).first);
  await tester.pump();
}

void main() {
  setUp(() => addTearDown(TitleServerConfigHolder().clear));

  testWidgets('收藏品列表可累加多行并可移除', (tester) async {
    await _pumpView(tester, MusicRiskFeatureMode.collectibles);

    expect(find.textContaining(AppStrings.collectiblesPendingEmpty), findsOne);

    await _addById(tester, AppStrings.collectiblesItemIdLabel, '250103');
    await _addById(tester, AppStrings.collectiblesItemIdLabel, '30021');

    expect(find.textContaining('#250103'), findsOneWidget);
    expect(find.textContaining('#30021'), findsOneWidget);
    expect(
      find.textContaining('${AppStrings.collectiblesPendingTitle} (2)'),
      findsOneWidget,
    );

    // 同一类型同一 ID 不应重复入列。
    await _addById(tester, AppStrings.collectiblesItemIdLabel, '30021');
    expect(
      find.textContaining('${AppStrings.collectiblesPendingTitle} (2)'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(AppStrings.listRemoveTooltip).first);
    await tester.pump();
    expect(find.textContaining('#250103'), findsNothing);
    expect(
      find.textContaining('${AppStrings.collectiblesPendingTitle} (1)'),
      findsOneWidget,
    );
  });

  testWidgets('解锁列表按勾选展开难度且添加后清空输入', (tester) async {
    await _pumpView(tester, MusicRiskFeatureMode.unlockMusic);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.unlockMusicIdLabel),
      '834',
    );
    await tester.tap(find.text(AppStrings.unlockMusicOption).first);
    await tester.tap(find.text(AppStrings.unlockMasterOption).first);
    await tester.pump();
    await tester.tap(find.text(AppStrings.listAddButton).first);
    await tester.pump();

    final row = find.textContaining('#834');
    expect(row, findsOneWidget);
    expect(tester.widget<Text>(row.first).data, contains('Master'));
    // 添加后输入与勾选应被清空，方便连续添加下一条。
    expect(
      tester.widget<TextField>(
        find.widgetWithText(TextField, AppStrings.unlockMusicIdLabel),
      ).controller!.text,
      isEmpty,
    );
  });

  testWidgets('自动退出登录并返回标题页默认勾选', (tester) async {
    await _pumpView(tester, MusicRiskFeatureMode.collectibles);

    expect(
      find.text(AppStrings.autoLogoutAndExit),
      findsOneWidget,
    );
    // 未勾选任何解锁项时，唯一处于选中态的复选框就是自动退登。
    final checked = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .where((c) => c.value == true)
        .toList();
    expect(checked, hasLength(1));
  });
}

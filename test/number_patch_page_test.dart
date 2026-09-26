import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/pages/number_patch_page.dart';
import 'package:ichino/services/user_all_payload_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  NumberPatchMode mode, {
  bool loggedIn = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  await TitleServerConfigHolder().update(
    const TitleServerConfig(
      titleServerUrl: 'http://127.0.0.1:9999',
      aesKey: '0123456789abcdef',
      aesIv: '0123456789abcdef',
      clientId: 'A63E01C2805',
    ),
  );

  tester.view.physicalSize = const Size(420, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: NumberPatchPage(
        userId: 42,
        cookies: 'JSESSIONID=X',
        loginDateTime: loggedIn ? 1 : null,
        loginId: loggedIn ? 7 : null,
        onExitToTitle: () async {},
        mode: mode,
      ),
    ),
  );
  await tester.pump();
}

Finder _runFinder(WidgetTester tester) => find.ancestor(
  of: find.text(AppStrings.numberPatchRun),
  matching: find.byType(FilledButton),
);

FilledButton _runButton(WidgetTester tester) =>
    tester.widget<FilledButton>(_runFinder(tester));

void main() {
  testWidgets('Rating 模式渲染总 Rating 输入框且可执行，无溢出', (tester) async {
    await _pumpPage(tester, NumberPatchMode.rating);

    expect(tester.takeException(), isNull);
    // 标题在 AppBar 与说明卡各出现一次。
    expect(find.text(AppStrings.ratingFeatureTitle), findsNWidgets(2));
    expect(find.text(AppStrings.ratingFeatureDesc), findsOneWidget);
    expect(find.text(AppStrings.ratingValueLabel), findsOneWidget);
    // 舞里程才有的「累加 / 直接设定」选择器不该出现。
    expect(find.text(AppStrings.maiMileModeLabel), findsNothing);
    expect(_runButton(tester).onPressed, isNotNull);
  });

  testWidgets('舞里程模式提供累加与设定两种方式', (tester) async {
    await _pumpPage(tester, NumberPatchMode.maiMile);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.maiMileModeAdd), findsOneWidget);
    expect(find.text(AppStrings.maiMileValueLabel), findsOneWidget);

    // 累加要基于服务器上的当前余额，没拉取数据前不猜、不预览。
    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('未登录时禁用执行', (tester) async {
    await _pumpPage(tester, NumberPatchMode.rating, loggedIn: false);

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.numberPatchNotLoggedIn), findsOneWidget);
    expect(_runButton(tester).onPressed, isNull);
  });

  testWidgets('Rating 超过 99999 时被拦下', (tester) async {
    await _pumpPage(tester, NumberPatchMode.rating);

    await tester.enterText(
      find.byType(TextField),
      '${UserAllPayloadBuilder.maxRating + 1}',
    );
    await tester.pump();
    await tester.tap(_runFinder(tester));
    await tester.pump();

    expect(
      find.text(
        AppStrings.numberPatchOutOfRange(
          0,
          UserAllPayloadBuilder.maxRating,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('舞里程模式接受 int32 两端的大数', (tester) async {
    await _pumpPage(tester, NumberPatchMode.maiMile);

    for (final value in [
      UserAllPayloadBuilder.maxValue,
      UserAllPayloadBuilder.minValue,
    ]) {
      await tester.enterText(find.byType(TextField), '$value');
      await tester.pump();
      await tester.tap(_runFinder(tester));
      await tester.pump();

      // 不该报越界；会走到拉数据/发包那步，这里只断言没有越界提示。
      expect(
        find.text(
          AppStrings.numberPatchOutOfRange(
            UserAllPayloadBuilder.minValue,
            UserAllPayloadBuilder.maxValue,
          ),
        ),
        findsNothing,
        reason: '$value 在 int32 区间内，不该被拦下',
      );
    }
  });

  testWidgets('空输入时给出填写提示', (tester) async {
    await _pumpPage(tester, NumberPatchMode.maiMile);

    await tester.tap(_runFinder(tester));
    await tester.pump();

    expect(find.text(AppStrings.maiMileNeedValue), findsOneWidget);
  });
}

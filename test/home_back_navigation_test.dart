import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/pages/home_page.dart';

/// 主页上的系统返回手势不能把 HomePage 弹掉（那会落回 Login Page，
/// 而且退登逻辑因为 didPop==true 根本不会跑）。
void main() {
  testWidgets('主页收到系统返回时结束应用而不是退回上一页', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(home: Text('login-root')),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute(builder: (_) => const HomePage(userId: 1, token: 't')),
    );
    await tester.pumpAndSettle();

    expect(find.text('login-root'), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // HomePage 仍在栈上：根路由被锁死。
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('login-root'), findsNothing);

    // 非 iOS 上应当走 SystemNavigator.pop 结束应用。
    expect(calls, contains('SystemNavigator.pop'));
  });
}

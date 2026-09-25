import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ichino/main.dart';

void main() {
  testWidgets('App renders login page with app title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Ichino'), findsWidgets);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

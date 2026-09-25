import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/models/user_rating.dart';
import 'package:ichino/pages/best50_page.dart';
import 'package:ichino/widgets/best50_poster.dart';

List<Best50CardData> _cards(int count, {String tag = 'a'}) => [
  for (var i = 0; i < count; i++)
    Best50CardData(
      musicId: 1000 + i,
      level: MusicLevel.values[i % MusicLevel.values.length],
      title: '$tag#$i',
      achievementText: '100.${(1000 + i).toString().padLeft(4, '0')}%',
      comboStatus: i % 5,
      syncStatus: i % 5,
      ra: 50 + i,
      rate: const [
        'D', 'C', 'B', 'BB', 'BBB', 'A', 'AA',
        'AAA', 'S', 'Sp', 'SS', 'SSp', 'SSS', 'SSSp',
      ][i % 14],
    ),
];

Future<void> _pumpPoster(
  WidgetTester tester, {
  required List<Best50CardData> best35,
  required List<Best50CardData> best15,
}) async {
  tester.view.physicalSize = const Size(1800, 1900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Best50Poster(
          userName: 'Test Player',
          iconId: 0,
          playerRating: 12345,
          best35: best35,
          best15: best15,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('卡片栅格坐标（对齐 Empurple）', () {
    test('每行 5 张，列距 320、首列 65', () {
      expect(Best50Poster.cardLeft(0), 65);
      expect(Best50Poster.cardLeft(4), 65 + 320 * 4);
      expect(Best50Poster.cardLeft(5), 65);
    });

    test('BEST35 区块固定从 350 起，每行下移 120', () {
      expect(Best50Poster.cardTopBest35(0), 350);
      expect(Best50Poster.cardTopBest35(4), 350);
      expect(Best50Poster.cardTopBest35(5), 350 + 120);
      expect(Best50Poster.cardTopBest35(34), 350 + 120 * 6);
    });

    test('BEST15 区块固定从 1250 起，与 BEST35 有多少条无关', () {
      expect(Best50Poster.cardTopBest15(0), 1250);
      expect(Best50Poster.cardTopBest15(5), 1250 + 120);
      expect(Best50Poster.cardTopBest15(14), 1250 + 120 * 2);
    });

    test('满 50 张时最后一张不越出底图', () {
      final right =
          Best50Poster.cardLeft(Best50Poster.columnsPerRow - 1) +
              Best50Poster.cardWidth;
      final bottom =
          Best50Poster.cardTopBest15(Best50Poster.maxBest15 - 1) +
              Best50Poster.cardHeight;
      expect(right, lessThanOrEqualTo(Best50Poster.canvasWidth));
      expect(bottom, lessThanOrEqualTo(Best50Poster.canvasHeight));
    });
  });

  group('Best50Poster 渲染', () {
    testWidgets('满员 35+15 按底图尺寸渲染且无溢出', (tester) async {
      await _pumpPoster(tester, best35: _cards(35), best15: _cards(15));

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(Best50Poster));
      expect(size.width, Best50Poster.canvasWidth);
      expect(size.height, Best50Poster.canvasHeight);
    });

    testWidgets('条目不足时不报错', (tester) async {
      await _pumpPoster(tester, best35: _cards(3), best15: const []);

      expect(tester.takeException(), isNull);
    });

    testWidgets('BEST35 未打满时 BEST15 仍固定在第二区块', (tester) async {
      // 回归用例：以前按 35+15 拼接后的全局序号算行，BEST35 不满 35 条时
      // BEST15 会整体上移、混进上半区。
      await _pumpPoster(tester, best35: _cards(3), best15: _cards(5, tag: 'b'));

      expect(tester.takeException(), isNull);
      final firstOf35 = tester.getTopLeft(find.text('a#0')).dy;
      final lastOf35 = tester.getTopLeft(find.text('a#2')).dy;
      final firstOf15 = tester.getTopLeft(find.text('b#0')).dy;
      final lastOf15 = tester.getTopLeft(find.text('b#4')).dy;

      expect(firstOf35, greaterThanOrEqualTo(Best50Poster.gridTopFirstBlock));
      expect(lastOf35, lessThan(Best50Poster.gridTopSecondBlock));
      expect(firstOf15, greaterThanOrEqualTo(Best50Poster.gridTopSecondBlock));
      expect(lastOf15, greaterThanOrEqualTo(Best50Poster.gridTopSecondBlock));
    });

    testWidgets('窄视口里海报仍保持底图尺寸（FittedBox 预览）', (tester) async {
      // 回归用例：InteractiveViewer 的 constrained 默认为 true，直接把固定尺寸的
      // 海报当子节点会被压成视口大小——底图压扁、Positioned 的卡片掉出画布被裁掉。
      // 中间垫一层 FittedBox 才是对的：视口拿到的是缩放后的显示，边界录到的仍是原尺寸。
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    constrained: false,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Best50Poster(
                        userName: 'Test Player',
                        iconId: 0,
                        playerRating: 12345,
                        best35: _cards(35),
                        best15: _cards(15, tag: 'b'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Best50Poster)),
        const Size(
          Best50Poster.canvasWidth,
          Best50Poster.canvasHeight,
        ),
      );
    });

    testWidgets('超出上限的条目被裁剪到 35+15', (tester) async {
      await _pumpPoster(tester, best35: _cards(60), best15: _cards(40, tag: 'b'));

      expect(tester.takeException(), isNull);
      // BEST35 只保留前 35 条，BEST15 只保留前 15 条。
      expect(find.text('a#34'), findsOneWidget);
      expect(find.text('a#35'), findsNothing);
      expect(find.text('b#14'), findsOneWidget);
      expect(find.text('b#15'), findsNothing);
    });
  });

  testWidgets('Best50Page 在未配置 Title Server 时给出提示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Best50Page(
            userId: 1,
            userName: 'Nobody',
            iconId: 0,
            playerRating: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.ticketNotConfigured), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}

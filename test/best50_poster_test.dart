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
        'D',
        'C',
        'B',
        'BB',
        'BBB',
        'A',
        'AA',
        'AAA',
        'S',
        'Sp',
        'SS',
        'SSp',
        'SSS',
        'SSSp',
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
      await _pumpPoster(
        tester,
        best35: _cards(3),
        best15: _cards(5, tag: 'b'),
      );

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

    testWidgets('constrained:false 下海报仍保持底图原尺寸', (tester) async {
      // InteractiveViewer(constrained:false) 会给孩子无界约束。不加限定的话
      // 海报会按 1762x1850 的逻辑尺寸直接铺开，视口里只看得到左上角。
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
        const Size(Best50Poster.canvasWidth, Best50Poster.canvasHeight),
      );
    });

    testWidgets('缩放到 contain 盒子后海报仍是原尺寸（导出分辨率不受影响）', (tester) async {
      // 页面现在用「有限大小的盒子 + FittedBox」把海报整体缩到视口内，
      // RepaintBoundary 在 FittedBox 内侧，所以 toImage 出来的还是
      // 1762x1850 * pixelRatio。这条守的是：别把 RepaintBoundary 挪到盒子外面。
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 视口 400x900，宽度是限制边，所以 contain 按宽算——和页面里的取法一致。
      const contain = 400 / Best50Poster.canvasWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: Best50Poster.canvasWidth * contain,
                height: Best50Poster.canvasHeight * contain,
                child: const FittedBox(
                  fit: BoxFit.fill,
                  child: Best50Poster(
                    userName: 'Test Player',
                    iconId: 0,
                    playerRating: 12345,
                    best35: [],
                    best15: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Best50Poster)),
        const Size(Best50Poster.canvasWidth, Best50Poster.canvasHeight),
      );
      // 显示盒子确实缩到视口内，所以一进来能看到完整一张。
      final boxSize = tester.getSize(find.byType(FittedBox).first);
      expect(boxSize.width, closeTo(400, 0.5));
      expect(boxSize.height, closeTo(Best50Poster.canvasHeight * contain, 0.5));
      expect(boxSize.height, lessThan(900));
    });

    testWidgets('超出上限的条目被裁剪到 35+15', (tester) async {
      await _pumpPoster(
        tester,
        best35: _cards(60),
        best15: _cards(40, tag: 'b'),
      );

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

import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/services/rating_calculator.dart';

/// achievementRaw 接口原值（百分比 * 10000）。
double _pct(int raw) => raw / 10000.0;

void main() {
  group('评级区间边界', () {
    const cases = <int, String>{
      0: 'D',
      99999: 'D',
      100000: 'D',
      499999: 'D',
      500000: 'C',
      599999: 'C',
      600000: 'B',
      699999: 'B',
      700000: 'BB',
      749999: 'BB',
      750000: 'BBB',
      799999: 'BBB',
      800000: 'A',
      899999: 'A',
      900000: 'AA',
      939999: 'AA',
      940000: 'AAA',
      969999: 'AAA',
      970000: 'S',
      979999: 'S',
      980000: 'Sp',
      989999: 'Sp',
      990000: 'SS',
      994999: 'SS',
      995000: 'SSp',
      999999: 'SSp',
      1000000: 'SSS',
      1004999: 'SSS',
      1005000: 'SSSp',
    };

    cases.forEach((raw, expected) {
      test('$raw => $expected', () {
        expect(RatingCalculator.compute(10.0, _pct(raw)).rate, expected);
      });
    });
  });

  group('RA 计算', () {
    test('低于 10% 时 RA 为 0', () {
      expect(RatingCalculator.computeRa(10.0, _pct(99999)), 0);
    });

    test('ds 10.0 / 100.1234% => 216', () {
      expect(RatingCalculator.compute(10.0, _pct(1001234)).ra, 216);
    });

    test('ds 10.0 / 99.0000% => 205 (整数截断)', () {
      expect(RatingCalculator.compute(10.0, _pct(990000)).ra, 205);
    });

    test('ds 10.0 / 100.5% 封顶 SSSp => 225', () {
      expect(RatingCalculator.compute(10.0, _pct(1005000)).ra, 225);
    });

    test('超出 100.5% 的达成率被夹到上限', () {
      final clamped = RatingCalculator.compute(10.0, _pct(1200000));
      final capped = RatingCalculator.compute(10.0, _pct(1005000));
      expect(clamped.ra, capped.ra);
      expect(clamped.rate, capped.rate);
    });

    test('定数 13.0 / 100% => 280', () {
      expect(RatingCalculator.compute(13.0, _pct(1000000)).ra, 280);
    });

    test('缺失定数 (ds=0) 时 RA 为 0', () {
      expect(RatingCalculator.computeRa(0.0, _pct(1005000)), 0);
    });
  });
}

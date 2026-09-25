/// RA / 评级计算，移植自 Empurple 的 `RatingCalculator`。
///
/// `achievement` 传入百分比数值（接口原值 1001234 => 100.1234），`ds` 为谱面定数。
class RaResult {
  final int ra;
  final String rate;

  const RaResult(this.ra, this.rate);
}

/// 达成率区间上界 / RA 系数 / 评级，顺序与 Empurple 的 when 分支一致。
const List<(int, int, String)> _bands = [
  (100000, 0, 'D'),
  (200000, 16, 'D'),
  (300000, 32, 'D'),
  (400000, 48, 'D'),
  (500000, 64, 'D'),
  (600000, 80, 'C'),
  (700000, 96, 'B'),
  (750000, 112, 'BB'),
  (799999, 120, 'BBB'),
  (800000, 128, 'BBB'),
  (900000, 136, 'A'),
  (940000, 152, 'AA'),
  (969999, 168, 'AAA'),
  (970000, 176, 'AAA'),
  (980000, 200, 'S'),
  (989999, 203, 'Sp'),
  (990000, 206, 'Sp'),
  (995000, 208, 'SS'),
  (999999, 211, 'SSp'),
  (1000000, 214, 'SSp'),
  (1004999, 216, 'SSS'),
  (1005000, 222, 'SSS'),
];

const int _maxAchievement = 1005000;
const int _ssspOffset = 224;

class RatingCalculator {
  RatingCalculator._();

  static int computeRa(double ds, double achievement) =>
      compute(ds, achievement).ra;

  static String computeRaRate(double ds, double achievement) =>
      compute(ds, achievement).rate;

  static RaResult compute(double ds, double achievement) {
    final achievementRaw =
        (achievement * 10000.0).round().clamp(0, _maxAchievement);
    var offset = _ssspOffset;
    var rate = 'SSSp';
    for (final (upperBound, bandOffset, bandRate) in _bands) {
      if (achievementRaw < upperBound) {
        offset = bandOffset;
        rate = bandRate;
        break;
      }
    }
    final scoreRate = (ds * 10.0).round();
    final ra = scoreRate * achievementRaw * offset ~/ 100000000;
    return RaResult(ra, rate);
  }
}

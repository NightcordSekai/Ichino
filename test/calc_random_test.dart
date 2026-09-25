import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/services/title_api_service.dart';

void main() {
  // UserGamePlaylog.playSpecial 在客户端里声明为 int(int32)。越界会让服务器
  // 反序列化失败并返回 HTTP 500，而旧实现有约一半概率越界。
  test('calcRandom 恒在 int32 范围内', () {
    const min = -2147483648;
    const max = 2147483647;
    for (var i = 0; i < 20000; i++) {
      final v = TitleApiService.calcRandom();
      expect(v, inInclusiveRange(min, max), reason: '第 $i 次采样得到 $v');
    }
  });
}

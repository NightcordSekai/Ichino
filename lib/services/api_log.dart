import 'package:flutter/foundation.dart';

/// 传输层调试日志。
///
/// 之前 `TitleApiService` / `ApiService` 里是 30 多处裸 `print` + `avoid_print`
/// 忽略注释，把请求包、响应包、`token`、`JSESSIONID` 全打到 stdout。这里统一
/// 收口：
/// - 默认只在 debug 构建输出（[enabled] 跟随 [kDebugMode]），release 下静默；
/// - 需要单独抓包时可以设置 `ApiLog.enabled = true`。
class ApiLog {
  ApiLog._();

  static bool enabled = kDebugMode;

  static void log(String message) {
    if (enabled) debugPrint(message);
  }
}

import 'dart:io';

/// 乐曲元数据是可重新下载的参考数据，放系统临时目录即可，
/// 不引入 path_provider（它经 path_provider_android 拖进 jni 插件，
/// jni 会在 Windows 上强行链接 jvm.lib）。
Future<String?> readTextCache(String fileName) async {
  try {
    final file = await _file(fileName);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return content.isEmpty ? null : content;
  } catch (_) {
    return null;
  }
}

Future<void> writeTextCache(String fileName, String content) async {
  try {
    await (await _file(fileName)).writeAsString(content);
  } catch (_) {
    // 缓存是尽力而为，失败只影响下次启动的加载速度。
  }
}

Future<File> _file(String fileName) async {
  final dir = Directory('${Directory.systemTemp.path}/ichino_cache');
  await dir.create(recursive: true);
  return File('${dir.path}/$fileName');
}

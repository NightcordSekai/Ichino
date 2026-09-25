import 'music_data_cache_native.dart'
    if (dart.library.html) 'music_data_cache_web.dart' as impl;

/// 乐曲元数据的磁盘缓存，Web 平台为空实现。读失败返回 null，写失败静默忽略。
Future<String?> readTextCache(String fileName) => impl.readTextCache(fileName);

Future<void> writeTextCache(String fileName, String content) =>
    impl.writeTextCache(fileName, content);

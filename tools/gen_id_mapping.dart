// 从机台数据包（G:\Package 这类整合包）里抽出 ID 映射表，生成
// data/id_mapping/*.json，供风险页做 ID 校对与名称展示。
//
// 产物放在 data/ 而不是 assets/：目前没有代码在运行时读它，放 assets/ 会被
// 原样打进每个安装包（约 1.2MB）。要接进 App 时再一起挪进 pubspec 的 assets。
//
// 用法（两种根可以混用，后面的覆盖前面的同 ID 行）：
//   dart run tools/gen_id_mapping.dart --package G:/Package
//   dart run tools/gen_id_mapping.dart --package G:/Package --data-root D:/A031OptDump/Root
//
// `--package` 会自动去找 `<pkg>/Sinmai_Data/StreamingAssets/A0xx/`；
// `--data-root` 直接把给定目录当一个数据根（像 A031OptDump/Root 那种单独导出的包）。
//
// 数据布局：`<root>/<表名>/<前缀><dataName>/<表名>.xml`，一个实体一个目录。
// 真正的 ID 在 XML 的 `<name><id>` 里，目录名只是 dataName（`icon/icon550201/Icon.xml`
// 的 name.id 其实是 1；`music/music111537` 的 name.id 是 111537，属宴曲段）。
//
// 多根合并按名字升序、后者覆盖同 ID 的行——客户端 DataManager.LoadData
// 就是这个语义（按 dirs 顺序遍历，`sortedDictionary[key] =` 直接覆写）。
// `--package` 下只认形如 `A???` 的目录，其余（Table/、RomConfig.xml 等）跳过。

import 'dart:convert';
import 'dart:io';

/// 每张表的抽取规则。
class _TableSpec {
  final String dirName;
  final String xmlFileName;

  /// 要抽的标量字段（`<tag>value</tag>`）。
  final List<String> scalars;

  /// 要抽的 StringID 字段（`<tag><id/><str/></tag>`），输出成 `<outKey>` 与 `<outKey>Name`。
  final List<String> stringIds;

  /// 输出文件名里的表名。
  const _TableSpec({
    required this.dirName,
    required this.xmlFileName,
    this.scalars = const [],
    this.stringIds = const [],
  });
}

/// `ItemKind`（`Net/VO/Mai2/ItemKind.cs`）到表目录的对应关系。
/// 角色（9）与万花筒钥匙（15）不走 userItemList，但 ID 照样要能查，所以一并收。
const List<(int itemKind, _TableSpec spec)> _itemTables = [
  (1, _TableSpec(dirName: 'plate', xmlFileName: 'Plate.xml', stringIds: ['name'])),
  (2, _TableSpec(dirName: 'title', xmlFileName: 'Title.xml', stringIds: ['name'])),
  (3, _TableSpec(dirName: 'icon', xmlFileName: 'Icon.xml', stringIds: ['name'])),
  (
    9,
    _TableSpec(dirName: 'chara', xmlFileName: 'Chara.xml', stringIds: ['name', 'genre']),
  ),
  (10, _TableSpec(dirName: 'partner', xmlFileName: 'Partner.xml', stringIds: ['name'])),
  (11, _TableSpec(dirName: 'frame', xmlFileName: 'Frame.xml', stringIds: ['name'])),
  (12, _TableSpec(dirName: 'ticket', xmlFileName: 'Ticket.xml', stringIds: ['name'])),
];

const _musicSpec = _TableSpec(
  dirName: 'music',
  xmlFileName: 'Music.xml',
  // lockType/subLockType 直接决定这首歌要不要靠 itemKind 5 解锁、
  // Re:Master 要不要额外条件（MusicLockType: Unlock=0 Lock=1 Challenge=2
  // Transmission=3 KaleidScope=4）。
  scalars: ['disable', 'lockType', 'subLockType', 'longMusic', 'version'],
  stringIds: ['name', 'artistName', 'genreName', 'AddVersion', 'eventName'],
);

const _mapSpec = _TableSpec(
  dirName: 'map',
  xmlFileName: 'Map.xml',
  scalars: ['IsCollabo', 'IsInfinity'],
  stringIds: ['name', 'IslandId', 'OpenEventId', 'ColorId', 'BonusMusicId'],
);

const _gateSpec = _TableSpec(
  dirName: 'kaleidxScopeGate',
  xmlFileName: 'KaleidxScopeGate.xml',
  scalars: ['gateType', 'positionId'],
  stringIds: ['name', 'eventName'],
);

/// 课题表是 keyId <-> gateId 的唯一桥（`GetKaleidxScopeCourseByKeyId` 扫的就是它）。
const _courseSpec = _TableSpec(
  dirName: 'kaleidxScopeCourse',
  xmlFileName: 'KaleidxScopeCourse.xml',
  stringIds: ['name', 'gateName', 'keyName'],
);

const _keySpec = _TableSpec(
  dirName: 'kaleidxScopeKey',
  xmlFileName: 'KaleidxScopeKey.xml',
  stringIds: ['name', 'gateName'],
);

/// 本地事件表只有名字与 `alwaysOpen`；**开关的日期窗口不在这里**，
/// 是服务器 `GetGameEventApi` 下发的 `GameEvent{startDate,endDate}`。
/// 所以这张表能用来看某个 eventName.id 属于什么活动，但判断「现在开没开」
/// 得去问服务器。
const _eventSpec = _TableSpec(
  dirName: 'event',
  xmlFileName: 'Event.xml',
  scalars: ['infoType', 'alwaysOpen', 'disableArea'],
  stringIds: ['name'],
);

void main(List<String> args) {
  final outDir = Directory(
    _argValue(args, '--out') ?? 'data/id_mapping',
  );

  final dataDirs = <String>[];

  // 整合包：先按 A??? 升序铺进来，让高编号的增补包覆盖基础包。
  final packageRoot = _argValue(args, '--package');
  if (packageRoot != null) {
    final assetsRoot = Directory(
      '${_norm(packageRoot)}/Sinmai_Data/StreamingAssets',
    );
    if (!assetsRoot.existsSync()) {
      stderr.writeln('找不到 ${assetsRoot.path}');
      exitCode = 1;
      return;
    }
    dataDirs.addAll(
      assetsRoot
          .listSync()
          .whereType<Directory>()
          .map((d) => _norm(d.path))
          .where((p) => RegExp(r'^A\d{3}$').hasMatch(_baseName(p)))
          .toList()
        ..sort(),
    );
  }

  // 单独导出的数据根（如 D:/A031OptDump/Root），按传参顺序追加，后面的赢。
  for (final extra in _argValues(args, '--data-root')) {
    final dir = Directory(_norm(extra));
    if (!dir.existsSync()) {
      stderr.writeln('找不到数据根 ${dir.path}');
      exitCode = 1;
      return;
    }
    dataDirs.add(_norm(extra));
  }

  if (dataDirs.isEmpty) {
    stderr.writeln('没有可用数据根，给 --package 或 --data-root');
    exitCode = 1;
    return;
  }

  outDir.createSync(recursive: true);

  final music = _mergeById(dataDirs, _musicSpec);
  final maps = _mergeById(dataDirs, _mapSpec);
  final gates = _mergeById(dataDirs, _gateSpec);
  final courses = _mergeById(dataDirs, _courseSpec);
  final keys = _mergeById(dataDirs, _keySpec);
  final events = _mergeById(dataDirs, _eventSpec);

  final items = <String, List<Map<String, dynamic>>>{};
  for (final (kind, spec) in _itemTables) {
    items['$kind'] = _mergeById(dataDirs, spec);
  }

  final writes = <String, Object>{
    'music.json': music,
    'maps.json': maps,
    'gates.json': {
      'gateList': gates,
      'courseList': courses,
      'keyList': keys,
    },
    'items.json': items,
    'events.json': events,
    'meta.json': {
      'dataDirs': dataDirs.map((p) => _baseName(p)).toList(),
      'counts': {
        'music': music.length,
        'map': maps.length,
        'gate': gates.length,
        'course': courses.length,
        'key': keys.length,
        'event': events.length,
        for (final (kind, _) in _itemTables)
          'itemKind$kind': items['$kind']!.length,
      },
    },
  };

  for (final entry in writes.entries) {
    final file = File('${outDir.path}/${entry.key}');
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(entry.value),
    );
    stdout.writeln('wrote ${file.path}');
  }
}

/// 扫描所有数据目录里该表的 XML，按 name.id 合并；同一 ID 后面出现的覆盖前面的。
List<Map<String, dynamic>> _mergeById(
  List<String> dataDirs,
  _TableSpec spec,
) {
  final byId = <int, Map<String, dynamic>>{};

  for (final root in dataDirs) {
    final dir = Directory('$root/${spec.dirName}');
    if (!dir.existsSync()) continue;

    for (final entity in dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => _baseName(f.path) == spec.xmlFileName)) {
      final row = _extract(entity.readAsStringSync(), spec);
      final id = row['id'];
      if (id is int) byId[id] = row;
    }
  }

  final ids = byId.keys.toList()..sort();
  return [for (final id in ids) byId[id]!];
}

Map<String, dynamic> _extract(String xml, _TableSpec spec) {
  final row = <String, dynamic>{};

  final primary = _stringId(xml, 'name');
  if (primary == null) return row;
  row['id'] = primary.id;
  row['name'] = primary.str;

  for (final tag in spec.stringIds) {
    if (tag == 'name') continue;
    final v = _stringId(xml, tag);
    if (v == null) continue;
    // ID 用来做关联与校验，str 只是给人看的，分开两个 key 存。
    row[tag] = v.id;
    row['${tag}Name'] = v.str;
  }

  for (final tag in spec.scalars) {
    final v = _scalar(xml, tag);
    if (v == null) continue;
    row[tag] = _asTyped(v);
  }

  return row;
}

class _StringId {
  final int id;
  final String str;
  const _StringId(this.id, this.str);
}

/// 取 `<tag>...</tag>` 平衡块内的 `<id>` 与 `<str>`。
_StringId? _stringId(String xml, String tag) {
  final block = _balancedBlock(xml, tag);
  if (block == null) return null;
  final idText = _scalar(block, 'id');
  if (idText == null) return null;
  final id = int.tryParse(idText);
  if (id == null) return null;
  return _StringId(id, _scalar(block, 'str') ?? '');
}

/// 第一个 `<tag>` … `</tag>` 平衡块的内容；`<tag/>` 视为空。
String? _balancedBlock(String xml, String tag) {
  final open = xml.indexOf('<$tag>');
  final selfClosed = xml.indexOf('<$tag ');
  final bareSelfClosed = xml.indexOf('<$tag/>');

  int start;
  if (open >= 0 && (selfClosed < 0 || open < selfClosed)) {
    start = open;
  } else if (bareSelfClosed >= 0) {
    return '';
  } else if (selfClosed >= 0) {
    start = selfClosed;
  } else {
    return null;
  }

  final closeTag = '</$tag>';
  var depth = 0;
  var i = start;
  while (i < xml.length) {
    final nextOpen = xml.indexOf('<$tag', i);
    final nextClose = xml.indexOf(closeTag, i);
    if (nextClose < 0) return null;

    if (nextOpen >= 0 && nextOpen < nextClose) {
      // 只有确实是开标签才算嵌套（后面跟 > / 空格 / /）。
      final after = xml[nextOpen + tag.length + 1];
      if (after == '>' || after == ' ' || after == '/') depth++;
      i = nextOpen + tag.length + 1;
      continue;
    }

    if (depth == 1 || depth == 0) {
      final contentStart = xml.indexOf('>', start) + 1;
      return xml.substring(contentStart.clamp(0, xml.length), nextClose);
    }
    depth--;
    i = nextClose + closeTag.length;
  }
  return null;
}

/// `<tag>value</tag>`，或 `<tag />` / `<tag/>` 当作空值忽略。
String? _scalar(String xml, String tag) {
  final open = xml.indexOf('<$tag>');
  if (open < 0) return null;
  final end = xml.indexOf('</$tag>', open);
  if (end < 0) return null;
  final raw = xml.substring(open + tag.length + 2, end).trim();
  if (raw.isEmpty) return null;
  return _decodeEntities(raw);
}

String _decodeEntities(String v) => v
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// `false`/`true` 转 bool，纯数字转 int，其余保留字符串。
Object _asTyped(String v) {
  if (v == 'true') return true;
  if (v == 'false') return false;
  final n = int.tryParse(v);
  return n ?? v;
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

/// 可重复参数（`--data-root A --data-root B`）。
List<String> _argValues(List<String> args, String name) {
  final out = <String>[];
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) out.add(args[i + 1]);
  }
  return out;
}

/// Windows 传参常见反斜杠，统一成 slash 再拼路径。
String _norm(String path) => path.replaceAll(r'\', '/');

String _baseName(String path) => _norm(path).split('/').last;

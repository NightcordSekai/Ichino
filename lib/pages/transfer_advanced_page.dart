import 'dart:convert';

import 'package:flutter/material.dart';

/// Editable JSON fields that feed into the UpsertUserAll payload.
/// Defaults match the Python script at E:\eaquira\sdgb\payload.py.
class AdvancedFields {
  String userItemList;
  String userMapList;
  String userLoginBonusList;
  String userGetPointList;
  String userTradeItemList;

  AdvancedFields({
    this.userItemList = '[]',
    this.userMapList = '[]',
    this.userLoginBonusList = '[]',
    this.userGetPointList = '[]',
    this.userTradeItemList = '[]',
  });

  List<dynamic>? _parse(String src) {
    try {
      final decoded = jsonDecode(src);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<dynamic> parsedUserItemList(String fb) => _parse(userItemList) ?? const [];
  List<dynamic> parsedUserMapList(String fb) => _parse(userMapList) ?? const [];
  List<dynamic> parsedUserLoginBonusList(String fb) => _parse(userLoginBonusList) ?? const [];
  List<dynamic> parsedUserGetPointList(String fb) => _parse(userGetPointList) ?? const [];
  List<dynamic> parsedUserTradeItemList(String fb) => _parse(userTradeItemList) ?? const [];

  Map<String, String> toJson() => {
        'userItemList': userItemList,
        'userMapList': userMapList,
        'userLoginBonusList': userLoginBonusList,
        'userGetPointList': userGetPointList,
        'userTradeItemList': userTradeItemList,
      };

  factory AdvancedFields.fromJson(Map<String, String> json) {
    return AdvancedFields(
      userItemList: json['userItemList'] ?? '[]',
      userMapList: json['userMapList'] ?? '[]',
      userLoginBonusList: json['userLoginBonusList'] ?? '[]',
      userGetPointList: json['userGetPointList'] ?? '[]',
      userTradeItemList: json['userTradeItemList'] ?? '[]',
    );
  }
}

/// Page that lets users paste raw JSON for advanced UpsertUserAll fields.
class TransferAdvancedPage extends StatefulWidget {
  final AdvancedFields initial;

  const TransferAdvancedPage({
    super.key,
    required this.initial,
  });

  @override
  State<TransferAdvancedPage> createState() => _TransferAdvancedPageState();
}

class _TransferAdvancedPageState extends State<TransferAdvancedPage> {
  late final List<_FieldMeta> _fields;

  @override
  void initState() {
    super.initState();
    _fields = [
      _FieldMeta('userItemList', '物品列表', widget.initial.userItemList),
      _FieldMeta('userMapList', '地图列表', widget.initial.userMapList),
      _FieldMeta('userLoginBonusList', '登录奖励', widget.initial.userLoginBonusList),
      _FieldMeta('userGetPointList', '获取点数', widget.initial.userGetPointList),
      _FieldMeta('userTradeItemList', '交易物品', widget.initial.userTradeItemList),
    ];
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.ctrl.dispose();
    }
    super.dispose();
  }

  AdvancedFields get values => AdvancedFields(
        userItemList: _fields[0].ctrl.text,
        userMapList: _fields[1].ctrl.text,
        userLoginBonusList: _fields[2].ctrl.text,
        userGetPointList: _fields[3].ctrl.text,
        userTradeItemList: _fields[4].ctrl.text,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('高级字段'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存并返回',
            onPressed: () => Navigator.of(context).pop(values),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '以下字段默认来自 Python 脚本 (空数组 [] )。如需覆盖，请粘贴完整 JSON 数组。错误格式将回退为 []。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final field in _fields) _buildFieldCard(theme, field),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(ThemeData theme, _FieldMeta field) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    field.ctrl.text = '[]';
                  },
                  child: Text('重置', style: theme.textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: field.ctrl,
              maxLines: 6,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldMeta {
  final String key;
  final String label;
  final TextEditingController ctrl;

  _FieldMeta(this.key, this.label, String initial)
      : ctrl = TextEditingController(text: initial);
}

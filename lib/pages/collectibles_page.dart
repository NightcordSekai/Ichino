import 'package:flutter/material.dart';

import '../config/strings.dart';
import 'music_risk_feature_view.dart';

/// 收藏品获取：逻辑参考 `eaquira/action/UnlockMusic.py`，
/// 通过上传 userItemList 道具获取收藏品 (UpsertUserAllApi)。
///
/// itemKind: 1=姓名框 2=称号 3=头像 10=搭档 11=背景板 12=功能票
class CollectiblesPage extends StatelessWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final String? lastLoginDate;
  final Future<void> Function()? onExitToTitle;

  const CollectiblesPage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.lastLoginDate,
    this.onExitToTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.collectiblesFeatureTitle),
      ),
      body: MusicRiskFeatureView(
        userId: userId,
        cookies: cookies,
        loginDateTime: loginDateTime,
        loginId: loginId,
        lastLoginDate: lastLoginDate,
        onExitToTitle: onExitToTitle,
        mode: MusicRiskFeatureMode.collectibles,
        featureTitle: AppStrings.collectiblesFeatureTitle,
        featureDesc: AppStrings.collectiblesFeatureDesc,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../config/strings.dart';
import 'music_risk_feature_view.dart';

/// Port of `eaquira/action/UnlockMusic.py`:
/// 上传 itemKind 5/6/7 道具解锁歌曲与谱面 (UpsertUserAllApi)。
class UnlockMusicPage extends StatelessWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final String? lastLoginDate;
  final Future<void> Function()? onExitToTitle;

  const UnlockMusicPage({
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
        title: const Text(AppStrings.unlockFeatureTitle),
      ),
      body: MusicRiskFeatureView(
        userId: userId,
        cookies: cookies,
        loginDateTime: loginDateTime,
        loginId: loginId,
        lastLoginDate: lastLoginDate,
        onExitToTitle: onExitToTitle,
        mode: MusicRiskFeatureMode.unlockMusic,
        featureTitle: AppStrings.unlockFeatureTitle,
        featureDesc: AppStrings.unlockFeatureDesc,
      ),
    );
  }
}

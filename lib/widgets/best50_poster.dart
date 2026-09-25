import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../models/user_rating.dart';

/// 海报上一张卡片所需的数据，由调用方解析好（曲名、定数、RA）。
class Best50CardData {
  final int musicId;
  final MusicLevel level;
  final String title;
  final String achievementText;
  final int comboStatus;
  final int syncStatus;
  final int ra;
  final String rate;

  const Best50CardData({
    required this.musicId,
    required this.level,
    required this.title,
    required this.achievementText,
    required this.comboStatus,
    required this.syncStatus,
    required this.ra,
    required this.rate,
  });

  /// DX 谱的 musicId 带 10000 偏移。
  bool get isDx => musicId > 10000;
}

/// Best 50 成绩海报，按 Empurple `Best50ImageRenderer` + `ImageBuilder` 的原始
/// 像素坐标复现：底图 `assets/b50/base.png` 为 1762x1850，卡片 300x100、
/// 每行 5 张、Best35 占 0..6 行、Best15 从第 7 行起跳到 1250 那条分隔带下方。
///
/// 顶部面板、舞萌DX logo、Best 35 / Best 15 药丸标签与页脚线都已经画在底图里，
/// 这里只叠加头像、昵称、Rating 行、50 张卡和页脚文字。
class Best50Poster extends StatelessWidget {
  static const double canvasWidth = 1762;
  static const double canvasHeight = 1850;
  static const double exportPixelRatio = 2;

  static const int maxBest35 = 35;
  static const int maxBest15 = 15;

  // 卡片栅格（与 Empurple 一致）
  static const int columnsPerRow = 5;
  static const double cardWidth = 300;
  static const double cardHeight = 100;
  static const double columnPitch = 320;
  static const double rowPitch = 120;
  static const double gridLeft = 65;
  static const double gridTopFirstBlock = 350;
  static const double gridTopSecondBlock = 1250;

  static const Color inkColor = Color(0xFF3D3D3D);
  static const Color cardColor = Color(0xFFEDEAFF);

  final String userName;
  final int iconId;
  final int playerRating;
  final List<Best50CardData> best35;
  final List<Best50CardData> best15;

  const Best50Poster({
    super.key,
    required this.userName,
    required this.iconId,
    required this.playerRating,
    required this.best35,
    required this.best15,
  });

  /// 两个区块各自独立排版：BEST35 固定从 [gridTopFirstBlock] 起、BEST15 固定从
  /// [gridTopSecondBlock] 起。不能按「35+15 拼接后的全局序号」算行，否则 BEST35
  /// 没打满时 BEST15 会整体上移、混进上半区。
  static double cardLeft(int indexInBlock) =>
      gridLeft + columnPitch * (indexInBlock % columnsPerRow);

  static double cardTopBest35(int indexInBlock) =>
      gridTopFirstBlock + rowPitch * (indexInBlock ~/ columnsPerRow);

  static double cardTopBest15(int indexInBlock) =>
      gridTopSecondBlock + rowPitch * (indexInBlock ~/ columnsPerRow);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards35 = best35.take(maxBest35).toList();
    final cards15 = best15.take(maxBest15).toList();
    final ra35 = cards35.fold(0, (sum, card) => sum + card.ra);
    final ra15 = cards15.fold(0, (sum, card) => sum + card.ra);

    return SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/b50/base.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (iconId > 0)
            Positioned(
              left: 115,
              top: 108,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  'https://assets2.lxns.net/maimai/icon/$iconId.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned(
            left: 260,
            top: 118,
            child: Text(
              userName.isEmpty ? AppStrings.unknownUser : userName,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1.15,
                color: inkColor,
                fontFamily: theme.textTheme.bodyLarge?.fontFamily,
              ),
            ),
          ),
          Positioned(
            left: 260,
            top: 178,
            child: Text(
              AppStrings.best50RatingSum(ra35, ra15),
              style: const TextStyle(
                fontSize: 24,
                height: 1.15,
                color: inkColor,
              ),
            ),
          ),
          Positioned(
            left: 260,
            top: 204,
            child: Text(
              AppStrings.rating(playerRating),
              style: const TextStyle(
                fontSize: 24,
                height: 1.15,
                color: inkColor,
              ),
            ),
          ),
          for (var i = 0; i < cards35.length; i++)
            Positioned(
              left: cardLeft(i),
              top: cardTopBest35(i),
              child: _RatingCard(data: cards35[i]),
            ),
          for (var i = 0; i < cards15.length; i++)
            Positioned(
              left: cardLeft(i),
              top: cardTopBest15(i),
              child: _RatingCard(data: cards15[i]),
            ),
          Positioned(
            left: 70,
            top: 1718,
            child: Text(
              AppStrings.best50Footer,
              style: const TextStyle(
                fontSize: 24,
                height: 1.15,
                color: inkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Best50CardData data;

  const _RatingCard({required this.data});

  static const Map<int, String> comboAssets = {
    1: 'FC',
    2: 'FCp',
    3: 'AP',
    4: 'APp',
  };
  static const Map<int, String> syncAssets = {
    1: 'FS',
    2: 'FSp',
    3: 'FSD',
    4: 'FSDp',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Best50Poster.cardWidth,
      height: Best50Poster.cardHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Best50Poster.cardColor,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                'https://assets2.lxns.net/maimai/jacket/'
                '${data.isDx ? data.musicId - 10000 : data.musicId}.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.black12,
                ),
              ),
            ),
          ),
          Positioned(
            left: 100,
            top: 20,
            width: data.isDx ? 124 : 188,
            child: Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                height: 1.15,
                color: Best50Poster.inkColor,
              ),
            ),
          ),
          Positioned(
            left: 100,
            top: 40,
            child: Text(
              data.achievementText,
              style: const TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.bold,
                color: Best50Poster.inkColor,
              ),
            ),
          ),
          if (data.isDx)
            Positioned(
              left: 230,
              top: 20,
              child: Image.asset(
                'assets/b50/DX.png',
                width: 60,
                height: 21,
                fit: BoxFit.contain,
              ),
            ),
          Positioned(
            left: 95,
            top: 67,
            child: Image.asset(
              'assets/b50/UI_TTR_Rank_${data.rate}.png',
              width: 55,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
          if (comboAssets[data.comboStatus] case final asset?)
            Positioned(
              left: 148,
              top: 66,
              child: Image.asset(
                'assets/b50/UI_CHR_PlayBonus_$asset.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          if (syncAssets[data.syncStatus] case final asset?)
            Positioned(
              left: 178,
              top: 66,
              child: Image.asset(
                'assets/b50/UI_CHR_PlayBonus_$asset.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          Positioned(
            left: 225,
            top: 70,
            child: Container(
              width: 68,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _LevelPill.background[data.level],
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'RA ${data.ra}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  color: Best50Poster.inkColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 难度色是游戏内语义色，与 Empurple 一致，不映射到 Material 色板。
class _LevelPill {
  static const Map<MusicLevel, Color> background = {
    MusicLevel.basic: Color(0xFF628C7B),
    MusicLevel.advanced: Color(0xFFB58300),
    MusicLevel.expert: Color(0xFFD37A7A),
    MusicLevel.master: Color(0xFF6750A4),
    MusicLevel.reMaster: Color(0xFFD0C8FF),
  };
}

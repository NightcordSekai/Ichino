import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/user_rating.dart';
import '../services/music_data_service.dart';
import '../services/png_export_service.dart';
import '../services/rating_calculator.dart';
import '../services/title_api_service.dart';
import '../widgets/best50_poster.dart';

/// Best 50 成绩图页面：负责取数与导出，海报本身在 `widgets/best50_poster.dart`。
///
/// GetUserRatingApi 只需要 userId（Cookie 是可选的，与 Empurple 的
/// `UserRatingRequest` + `MaimaiApiClient` 一致），所以 Preview API 模式、
/// 未登录游戏服务器时同样能拉出 B50，只是拿不到 FC/AP、FS 这类详细标记。
class Best50Page extends StatefulWidget {
  final int userId;
  final String? cookies;
  final String userName;
  final int iconId;
  final int playerRating;

  const Best50Page({
    super.key,
    required this.userId,
    this.cookies,
    required this.userName,
    required this.iconId,
    required this.playerRating,
  });

  @override
  State<Best50Page> createState() => _Best50PageState();
}

class _Best50PageState extends State<Best50Page> {
  final GlobalKey _posterKey = GlobalKey();

  UserRatingBean? _rating;
  String? _error;
  bool _loading = true;
  bool _exporting = false;
  bool _musicReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(Best50Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 本页在 IndexedStack 里会先于 preview/登录请求被构建，cookies 到位后补一次加载。
    if (oldWidget.cookies != widget.cookies &&
        (_rating == null || _error != null)) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (!TitleServerConfigHolder().isConfigured) {
      _fail(AppStrings.ticketNotConfigured);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = TitleApiService(
        TitleServerConfigHolder().config!,
        cookies: widget.cookies,
      );
      final rating = await service.getUserRatingTyped(widget.userId);
      if (!mounted) return;
      setState(() {
        _rating = rating;
        _loading = false;
      });

      // 曲名/定数缺失时仍能出图（RA 会是 0），所以不当作致命错误。
      await MusicDataService.instance.load();
      if (!mounted) return;
      setState(() => _musicReady = true);
    } on TitleApiException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('$e');
    }
  }

  void _fail(String message) {
    setState(() {
      _loading = false;
      _rating = null;
      _error = message;
    });
  }

  List<Best50CardData> _resolve(List<UserRatingItemBean> items) {
    final music = MusicDataService.instance;
    return items.map((item) {
      final result = RatingCalculator.compute(
        music.getDs(item.musicId, item.level),
        item.achievementPercent,
      );
      return Best50CardData(
        musicId: item.musicId,
        level: item.musicLevel,
        title: music.getTitle(item.musicId),
        achievementText: item.achievementText,
        comboStatus: item.comboStatus,
        syncStatus: item.syncStatus,
        ra: result.ra,
        rate: result.rate,
      );
    }).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary =
          _posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('海报尚未完成布局');

      final image = await boundary.toImage(pixelRatio: Best50Poster.exportPixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('PNG 编码失败');

      final path = await exportPng(
        byteData.buffer.asUint8List(),
        'best50_${widget.userId}.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.best50Exported(path))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.best50ExportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rating = _rating;
    if (rating == null) {
      return _StateView(
        message: _error ?? AppStrings.loadFailed,
        onRetry: _bootstrap,
      );
    }

    if (rating.ratingList.isEmpty && rating.newRatingList.isEmpty) {
      return _StateView(
        message: AppStrings.best50Empty,
        onRetry: _bootstrap,
        icon: Icons.bar_chart_outlined,
      );
    }

    final best35 = _resolve(
      rating.ratingList.take(Best50Poster.maxBest35).toList(),
    );
    final best15 = _resolve(
      rating.newRatingList.take(Best50Poster.maxBest15).toList(),
    );

    return Scaffold(
      body: Column(
        children: [
          if (!_musicReady)
            _NoticeBanner(theme: theme, text: AppStrings.best50NoMusicData),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 20),
                label: Text(
                  _exporting
                      ? AppStrings.best50Exporting
                      : AppStrings.best50Export,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(24),
              // FittedBox 会按视口把固定尺寸的海报缩出来；它给子节点无限约束，
              // 所以海报仍保持 1762x1850，RepaintBoundary 录到的也是原始尺寸
              // （祖先变换不会被烘进边界里），导出不会糊。
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: _posterKey,
                  child: Best50Poster(
                    userName: widget.userName,
                    iconId: widget.iconId,
                    playerRating: widget.playerRating,
                    best35: best35,
                    best15: best15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 页面级辅助组件（非海报部分，跟随 Ichino 现有卡片/横幅风格）
// =============================================================================

class _NoticeBanner extends StatelessWidget {
  final ThemeData theme;
  final String text;

  const _NoticeBanner({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const _StateView({
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

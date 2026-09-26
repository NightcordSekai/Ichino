import 'dart:async';

import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';

/// 数值修改：Rating 与舞里程。两者的流程一模一样（拉数据 → 改一个数 →
/// UpsertUserAll），差别只在改哪个字段，所以合成一个带模式的视图。
enum NumberPatchMode {
  /// 总 Rating：`userData.playerRating` + `userRating.rating`
  rating,

  /// 舞里程：`userData.point`（余额），可带上 `totalPoint`（累计）
  maiMile,
}

class NumberPatchPage extends StatelessWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final Future<void> Function()? onExitToTitle;
  final NumberPatchMode mode;

  const NumberPatchPage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final isRating = mode == NumberPatchMode.rating;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRating
              ? AppStrings.ratingFeatureTitle
              : AppStrings.maiMileFeatureTitle,
        ),
      ),
      body: NumberPatchView(
        userId: userId,
        cookies: cookies,
        loginDateTime: loginDateTime,
        loginId: loginId,
        onExitToTitle: onExitToTitle,
        mode: mode,
        featureTitle: isRating
            ? AppStrings.ratingFeatureTitle
            : AppStrings.maiMileFeatureTitle,
        featureDesc: isRating
            ? AppStrings.ratingFeatureDesc
            : AppStrings.maiMileFeatureDesc,
      ),
    );
  }
}

enum _Step { idle, fetchData, upload, logout, complete, failed }

class NumberPatchView extends StatefulWidget {
  final int userId;
  final String? cookies;

  /// 来自 HomePage 启动时的 UserLoginApi，为 `null` 表示没有有效登录态。
  final int? loginDateTime;
  final int? loginId;
  final Future<void> Function()? onExitToTitle;

  final NumberPatchMode mode;
  final String featureTitle;
  final String featureDesc;

  const NumberPatchView({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
    required this.mode,
    required this.featureTitle,
    required this.featureDesc,
  });

  @override
  State<NumberPatchView> createState() => _NumberPatchViewState();
}

class _NumberPatchViewState extends State<NumberPatchView> {
  /// 与解锁/收藏品/旅行伙伴一致：这些操作不写真实成绩，
  /// playlog 沿用同一条占位记录，Rating 修改需要它来带 before/after。
  static const int _placeholderMusicId = 11538;

  final _valueController = TextEditingController();

  Map<String, Map<String, dynamic>> _userAllData = const {};
  bool _maiMileAdd = true;

  bool _loading = false;
  bool _running = false;
  bool _autoLogout = true;
  _Step _step = _Step.idle;
  String _stepMessage = '';

  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  bool get _isRating => widget.mode == NumberPatchMode.rating;
  bool get _loggedIn => widget.loginDateTime != null;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
  }

  @override
  void didUpdateWidget(covariant NumberPatchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginDateTime != widget.loginDateTime) {
      _syncCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _valueController.dispose();
    super.dispose();
  }

  void _syncCooldown() {
    _cooldownTimer?.cancel();
    final loginDateTime = widget.loginDateTime;
    if (loginDateTime == null) {
      setState(() => _cooldownRemaining = 0);
      return;
    }
    setState(() => _cooldownRemaining = _computeRemaining(loginDateTime));
    if (_cooldownRemaining <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _computeRemaining(loginDateTime);
      setState(() => _cooldownRemaining = remaining);
      if (remaining <= 0) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
    });
  }

  int _computeRemaining(int loginDateTime) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining =
        AppStrings.ticketCooldownSeconds - (nowSec - loginDateTime);
    return remaining < 0 ? 0 : remaining;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// 从已拉取的 GetUserDataApi 里读当前值，供「累加」和界面上的当前值展示。
  int _currentOf(Map<String, Map<String, dynamic>> data, String field) {
    final userData = data['GetUserDataApi']?['userData'];
    if (userData is! Map) return 0;
    return _toInt(userData[field]);
  }

  int get _currentRating => _currentOf(_userAllData, 'playerRating');
  int get _currentPoint => _currentOf(_userAllData, 'point');

  /// Rating 的区间是游戏内的 0~99999；舞里程是整个 int32，允许负值
  /// （累加模式填负数就是扣里程）。
  int get _min => _isRating ? 0 : UserAllPayloadBuilder.minValue;
  int get _max => _isRating
      ? UserAllPayloadBuilder.maxRating
      : UserAllPayloadBuilder.maxValue;

  int _clamp(int v) => v < _min ? _min : (v > _max ? _max : v);

  /// 界面上「将写入」的预览值。未拉取数据时按 0 起算，仅用于提示。
  int get _previewTarget {
    final input = int.tryParse(_valueController.text.trim());
    if (input == null) return 0;
    if (_isRating) return _clamp(input);
    return _maiMileAdd ? _clamp(_currentPoint + input) : _clamp(input);
  }

  String? _checkInput() {
    final text = _valueController.text.trim();
    final input = int.tryParse(text);
    if (input == null) {
      return _isRating ? AppStrings.ratingNeedValue : AppStrings.maiMileNeedValue;
    }
    if (input < _min || input > _max) {
      return AppStrings.numberPatchOutOfRange(_min, _max);
    }
    if (_isRating) return null;
    if (_maiMileAdd && input == 0) return AppStrings.maiMileNeedValue;
    return null;
  }

  Future<void> _fetchData() async {
    if (!TitleServerConfigHolder().isConfigured) return;
    setState(() => _loading = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final data = await service.fetchUserAllData(widget.userId);
      if (!mounted) return;
      setState(() {
        _userAllData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('${AppStrings.loadFailed}: $e');
    }
  }

  Future<void> _run() async {
    if (!TitleServerConfigHolder().isConfigured) {
      _snack(AppStrings.ticketNotConfigured);
      return;
    }
    final loginDateTime = widget.loginDateTime;
    final loginId = widget.loginId;
    if (loginDateTime == null || loginId == null) {
      _snack(AppStrings.numberPatchNotLoggedIn);
      return;
    }
    if (_cooldownRemaining > 0) {
      _snack(AppStrings.numberPatchCooldownNotice(_cooldownRemaining));
      return;
    }
    final inputError = _checkInput();
    if (inputError != null) {
      _snack(inputError);
      return;
    }
    final input = int.parse(_valueController.text.trim());

    setState(() => _running = true);

    try {
      final config = TitleServerConfigHolder().config!;
      final service = TitleApiService(config, cookies: widget.cookies);
      final builder = UserAllPayloadBuilder(config);

      var data = _userAllData;
      if (data.isEmpty) {
        _updateStep(_Step.fetchData);
        data = await service.fetchUserAllData(widget.userId);
        if (mounted) setState(() => _userAllData = data);
      }

      _updateStep(_Step.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: _placeholderMusicData(),
        generalUserInfo: data,
      );

      final String resultMessage;
      if (_isRating) {
        builder.applyRatingPatch(packet, rating: input);
        resultMessage =
            '${AppStrings.ratingSuccess} → ${_clamp(input)}';
      } else {
        final current = _currentOf(data, 'point');
        final total = _currentOf(data, 'totalPoint');
        final point = _maiMileAdd ? _clamp(current + input) : _clamp(input);
        builder.applyMaiMilePatch(
          packet,
          point: point,
          // 累加才动累计值；「直接设定」只覆写余额，累计是历史事实。
          totalPoint: _maiMileAdd ? _clamp(total + input) : null,
        );
        resultMessage = '${AppStrings.maiMileSuccess} → $point';
      }

      await service.upsertUserAll(packet, widget.userId);
      _updateStep(_Step.complete, resultMessage);

      if (_autoLogout && widget.onExitToTitle != null) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _updateStep(_Step.logout, AppStrings.exitingToTitle);
        await widget.onExitToTitle!();
      }
    } on TitleApiException catch (e) {
      _updateStep(_Step.failed, e.message);
    } catch (e) {
      _updateStep(_Step.failed, '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Map<String, dynamic> _placeholderMusicData() => {
    'musicId': _placeholderMusicId,
    'level': 0,
    'playCount': 1,
    'achievement': 0,
    'comboStatus': 0,
    'syncStatus': 0,
    'deluxscoreMax': 0,
    'scoreRank': 0,
    'extNum1': 0,
  };

  void _updateStep(_Step step, [String? message]) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _stepMessage = message ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: responsiveBody(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_loggedIn)
              _notice(theme, AppStrings.numberPatchNotLoggedIn, error: true),
            if (_loggedIn && _cooldownRemaining > 0)
              _notice(
                theme,
                AppStrings.numberPatchCooldownNotice(_cooldownRemaining),
              ),
            _descCard(theme),
            const SizedBox(height: 12),
            _inputCard(theme),
            const SizedBox(height: 12),
            _fetchCard(theme),
            const SizedBox(height: 12),
            _autoLogoutToggle(theme),
            const SizedBox(height: 12),
            _runButton(theme),
            if (_step != _Step.idle) ...[
              const SizedBox(height: 16),
              _progressCard(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice(ThemeData theme, String text, {bool error = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: error
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: error
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _descCard(ThemeData theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isRating ? Icons.speed : Icons.commute,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.featureTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.featureDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard(ThemeData theme) {
    final enabled = !_running;
    final hasInput = int.tryParse(_valueController.text.trim()) != null;

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _valueController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _isRating
                  ? AppStrings.ratingValueLabel
                  : AppStrings.maiMileValueLabel,
              hintText: _isRating
                  ? AppStrings.ratingValueHint
                  : AppStrings.maiMileValueHint,
              helperText: AppStrings.numberPatchRangeHint(_min, _max),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          if (!_isRating) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _maiMileAdd ? 1 : 0,
              decoration: InputDecoration(
                labelText: AppStrings.maiMileModeLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              items: [
                DropdownMenuItem(
                  value: 1,
                  child: Text(
                    AppStrings.maiMileModeAdd,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                DropdownMenuItem(
                  value: 0,
                  child: Text(
                    AppStrings.maiMileModeSet,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              onChanged: enabled
                  ? (v) => setState(() => _maiMileAdd = (v ?? 1) == 1)
                  : null,
            ),
          ],
          // 累加要基于服务器上的当前余额，没拉取数据前预览不了，就别猜一个 0。
          if (hasInput && (_isRating || _userAllData.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Text(
              _previewLine,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _previewLine {
    final label = _isRating
        ? AppStrings.ratingCurrentValue
        : AppStrings.maiMileCurrentBalance;
    final current = _isRating ? _currentRating : _currentPoint;
    return AppStrings.numberPatchPreview(label, current, _previewTarget);
  }

  Widget _fetchCard(ThemeData theme) {
    final hasData = _userAllData.isNotEmpty;
    final current = _isRating ? _currentRating : _currentPoint;
    final label = _isRating
        ? AppStrings.ratingCurrentValue
        : AppStrings.maiMileCurrentBalance;

    return _card(
      theme,
      child: Row(
        children: [
          Icon(
            hasData ? Icons.check_circle : Icons.download,
            size: 18,
            color: hasData ? Colors.green : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasData
                  ? '$label: $current'
                  : AppStrings.unlockNoData,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: hasData
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: _loading || _running ? null : _fetchData,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                _loading
                    ? AppStrings.unlockFetching
                    : hasData
                    ? AppStrings.unlockRefetch
                    : AppStrings.unlockFetchData,
                style: theme.textTheme.labelSmall,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoLogoutToggle(ThemeData theme) {
    final enabled = widget.onExitToTitle != null && !_running;
    return _card(
      theme,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? () => setState(() => _autoLogout = !_autoLogout) : null,
        child: Row(
          children: [
            Checkbox(
              value: _autoLogout,
              onChanged: enabled
                  ? (v) => setState(() => _autoLogout = v ?? false)
                  : null,
            ),
            Expanded(
              child: Text(
                AppStrings.autoLogoutAndExit,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _running || !_loggedIn ? null : _run,
        icon: _running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send, size: 20),
        label: Text(
          _running ? AppStrings.unlockRunning : AppStrings.numberPatchRun,
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _progressCard(ThemeData theme) {
    final isFailed = _step == _Step.failed;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepRow(theme, _Step.fetchData, AppStrings.unlockStepFetch),
          _stepRow(theme, _Step.upload, AppStrings.numberPatchStepUpload),
          if (_autoLogout)
            _stepRow(theme, _Step.logout, AppStrings.stepLogout),
          if (_stepMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFailed
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _stepMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: isFailed
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(ThemeData theme, _Step step, String label) {
    final order = [_Step.fetchData, _Step.upload, _Step.logout, _Step.complete];
    final current = _step == _Step.failed ? _Step.upload : _step;
    final done = order.indexOf(current) > order.indexOf(step);
    final active = _step == step;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : active
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: done
                ? Colors.green
                : active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

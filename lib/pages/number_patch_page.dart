
import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/step_progress.dart';

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

class _NumberPatchViewState extends State<NumberPatchView>
    with CooldownMixin<NumberPatchView> {
  final _valueController = TextEditingController();

  Map<String, Map<String, dynamic>> _userAllData = const {};
  bool _maiMileAdd = true;

  bool _loading = false;
  bool _running = false;
  bool _autoLogout = true;
  RiskStep _step = RiskStep.idle;
  String _stepMessage = '';

  bool get _isRating => widget.mode == NumberPatchMode.rating;

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _snack(String message) => context.showSnack(message);

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
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
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
    if (cooldownRemaining > 0) {
      _snack(AppStrings.numberPatchCooldownNotice(cooldownRemaining));
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
      final service = TitleApiService.fromHolder(cookies: widget.cookies)!;
      final builder = UserAllPayloadBuilder(service.config);

      var data = _userAllData;
      if (data.isEmpty) {
        _updateStep(RiskStep.fetchData);
        data = await service.fetchUserAllData(widget.userId);
        if (mounted) setState(() => _userAllData = data);
      }

      _updateStep(RiskStep.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: UserAllPayloadBuilder.placeholderMusicData(),
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
      _updateStep(RiskStep.complete, resultMessage);

      if (_autoLogout && widget.onExitToTitle != null) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _updateStep(RiskStep.logout, AppStrings.exitingToTitle);
        await widget.onExitToTitle!();
      }
    } on TitleApiException catch (e) {
      _updateStep(RiskStep.failed, e.message);
    } catch (e) {
      _updateStep(RiskStep.failed, '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _updateStep(RiskStep step, [String? message]) {
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
            if (!isLoggedIn)
              const AppNotice(AppStrings.numberPatchNotLoggedIn, error: true),
            if (isLoggedIn && cooldownRemaining > 0)
              AppNotice(
                AppStrings.numberPatchCooldownNotice(cooldownRemaining),
              ),
            _descCard(theme),
            const SizedBox(height: 12),
            _inputCard(theme),
            const SizedBox(height: 12),
            _fetchCard(theme),
            const SizedBox(height: 12),
            AutoLogoutToggle(
              value: _autoLogout,
              enabled: widget.onExitToTitle != null && !_running,
              onChanged: (v) => setState(() => _autoLogout = v),
            ),
            const SizedBox(height: 12),
            _runButton(theme),
            if (_step != RiskStep.idle) ...[
              const SizedBox(height: 16),
              StepProgressCard(
                step: _step,
                message: _stepMessage,
                steps: [
                  (RiskStep.fetchData, AppStrings.unlockStepFetch),
                  (RiskStep.upload, AppStrings.numberPatchStepUpload),
                  if (_autoLogout) (RiskStep.logout, AppStrings.stepLogout),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _descCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: _isRating ? Icons.speed : Icons.commute,
            title: widget.featureTitle,
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

    return AppCard(
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

    return AppCard(
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

  Widget _runButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _running || !isLoggedIn ? null : _run,
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
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/strings.dart';

/// 功能页共用的「登录后冷却」计时。
///
/// 六个功能页（功能票 / 数值修改 / 旅行伙伴 / 一键跑图 / 万花筒 / 解锁）原本
/// 各自抄了一份 `Timer.periodic` + `_computeRemaining`，这里收口成一个 mixin。
///
/// 用法：
/// ```dart
/// class _FooState extends State<Foo> with CooldownMixin<Foo> {
///   @override
///   int? get cooldownLoginDateTime => widget.loginDateTime;
/// }
/// ```
/// 页面**不要**再自己覆写 `initState` / `didUpdateWidget` / `dispose` 里与冷却
/// 相关的逻辑；如需覆写，记得调用 `super`。
mixin CooldownMixin<T extends StatefulWidget> on State<T> {
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;
  int? _appliedLoginDateTime;

  /// 当前会话的 `UserLoginApi` 时间戳；`null` 表示没有有效登录态。
  int? get cooldownLoginDateTime;

  bool get isLoggedIn => cooldownLoginDateTime != null;

  int get cooldownRemaining => _cooldownRemaining;

  @override
  void initState() {
    super.initState();
    _applyCooldown();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (cooldownLoginDateTime != _appliedLoginDateTime) {
      _applyCooldown();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    super.dispose();
  }

  void _applyCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _appliedLoginDateTime = cooldownLoginDateTime;

    final loginDateTime = _appliedLoginDateTime;
    if (loginDateTime == null) {
      _setRemaining(0);
      return;
    }

    _setRemaining(_computeRemaining(loginDateTime));
    if (_cooldownRemaining <= 0) return;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _setRemaining(_computeRemaining(loginDateTime));
      if (_cooldownRemaining <= 0) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
    });
  }

  void _setRemaining(int value) {
    if (!mounted) {
      _cooldownRemaining = value;
      return;
    }
    setState(() => _cooldownRemaining = value);
  }

  int _computeRemaining(int loginDateTime) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining =
        AppStrings.ticketCooldownSeconds - (nowSec - loginDateTime);
    return remaining < 0 ? 0 : remaining;
  }
}

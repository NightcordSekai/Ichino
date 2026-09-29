import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../models/session_model.dart';
import '../models/session_share.dart';
import '../services/file_picker_service.dart';
import '../services/qr_service.dart';
import '../widgets/app_notice.dart';
import 'home_page.dart';
import 'settings_page.dart';

/// 登录页：粘贴 / 识别 QR 令牌，走 Aime 登录后进入主页。
///
/// 也接受主页导出的「连接信息」（实验性）：那是一串 Base64，直接续上原有会话。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _qrController = TextEditingController();
  String _qrCode = '';
  String _rawInput = '';
  SessionShare? _share;
  bool _loading = false;
  bool _forcePreviewApi = false;

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  void _onQRContentChanged(String value) {
    final text = value.trim();
    setState(() {
      _rawInput = text;
      _qrCode = SessionModel.extractQRCode(text);
      _share = SessionShare.tryDecode(text);
    });
  }

  Future<void> _onUploadQR() async {
    try {
      final bytes = await pickImageBytes();
      if (bytes == null) return;

      final result = await decodeQRFromBytes(bytes);

      if (result != null && result.isNotEmpty) {
        _qrController.text = result;
        setState(() {
          _rawInput = result.trim();
          _qrCode = SessionModel.extractQRCode(result);
          _share = SessionShare.tryDecode(result);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.qrScanSuccess)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.qrScanFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.qrScanError}: $e')),
        );
      }
    }
  }

  Future<void> _onLogin() async {
    if (_qrCode.isEmpty) return;

    // 令牌是粘贴内容的后 64 位，前缀可能在截取之后就没了，所以要拿原文判断；
    // 认不出来时必须给提示，否则点了按钮一声不响，像是坏了。
    if (!_rawInput.contains('SGWCMAID')) {
      context.showSnack(AppStrings.qrTokenUnrecognized);
      return;
    }
    setState(() => _loading = true);

    try {
      final result = await SessionModel.instance.loginWithQr(_qrCode);

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HomePage(
              userId: result.userId,
              token: result.token,
              forcePreviewApi: _forcePreviewApi,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppStrings.loginFailed} (errorID: ${result.errorId})',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.requestFailed}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 实验性：用主页导出的连接信息恢复会话。带可用 JSESSIONID 就直接续上那次登录，
  /// 否则退回用令牌重新登录。
  Future<void> _onRestoreSession() async {
    final share = _share;
    if (share == null) return;

    setState(() => _loading = true);
    try {
      final result = await SessionModel.instance.restoreFromShare(share);
      if (!mounted) return;
      context.showSnack(
        result.reusedCookie
            ? AppStrings.sessionRestoreCookie
            : AppStrings.sessionRestoreToken,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HomePage(
            userId: share.userId,
            token: share.token,
            sessionRestored: true,
            initialUserData: result.userData,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        context.showSnack('${AppStrings.sessionRestoreFailed}: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRestore = _share != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppStrings.settingsTooltip,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: responsiveBody(
            context,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 48),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.key,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.qrCodeToken,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _qrController,
                          maxLines: 3,
                          onChanged: _onQRContentChanged,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                          decoration: InputDecoration(
                            hintText: AppStrings.qrHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                if (isRestore)
                  const AppNotice(
                    AppStrings.sessionShareDetected,
                    icon: Icons.science_outlined,
                  ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _onUploadQR,
                        icon: const Icon(Icons.image, size: 20),
                        label: const Text(AppStrings.uploadQR),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isRestore
                            ? (_loading ? null : _onRestoreSession)
                            : (_qrCode.isNotEmpty && !_loading)
                            ? _onLogin
                            : null,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isRestore ? Icons.link : Icons.arrow_forward,
                                size: 20,
                              ),
                        label: Text(
                          isRestore
                              ? (_loading
                                    ? AppStrings.restoringSession
                                    : AppStrings.restoreSession)
                              : (_loading
                                    ? AppStrings.loggingIn
                                    : AppStrings.login),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isRestore)
                  CheckboxListTile(
                    value: _forcePreviewApi,
                    onChanged: (v) =>
                        setState(() => _forcePreviewApi = v ?? false),
                    title: const Text(AppStrings.forcePreviewApi),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

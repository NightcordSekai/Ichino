import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../config/title_server_config.dart';

class SettingsPage extends StatefulWidget {
  final bool showAppBar;

  const SettingsPage({super.key, this.showAppBar = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _aesKeyController = TextEditingController();
  final _aesIvController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _regionIdController = TextEditingController(text: '1');
  final _placeIdController = TextEditingController(text: '1403');
  final _obfuscateController = TextEditingController(text: 'LatuAa81');
  final _apiVersionController = TextEditingController(text: '1.53');

  @override
  void initState() {
    super.initState();
    final config = TitleServerConfigHolder().config;
    if (config != null) {
      _urlController.text = config.titleServerUrl;
      _aesKeyController.text = config.aesKey;
      _aesIvController.text = config.aesIv;
      _clientIdController.text = config.clientId;
      _regionIdController.text = '${config.regionId}';
      _placeIdController.text = '${config.placeId}';
      _obfuscateController.text = config.obfuscateParam;
      _apiVersionController.text = config.apiVersion;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _aesKeyController.dispose();
    _aesIvController.dispose();
    _clientIdController.dispose();
    _regionIdController.dispose();
    _placeIdController.dispose();
    _obfuscateController.dispose();
    _apiVersionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await TitleServerConfigHolder().update(TitleServerConfig(
      titleServerUrl: _urlController.text.trim(),
      aesKey: _aesKeyController.text.trim(),
      aesIv: _aesIvController.text.trim(),
      clientId: _clientIdController.text.trim(),
      regionId: int.tryParse(_regionIdController.text.trim()) ?? 1,
      placeId: int.tryParse(_placeIdController.text.trim()) ?? 1403,
      obfuscateParam: _obfuscateController.text.trim(),
      apiVersion: _apiVersionController.text.trim(),
    ));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(AppStrings.titleServerSettings),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(theme, AppStrings.required, [
                  _buildField(
                    controller: _urlController,
                    label: AppStrings.labelTitleServerUrl,
                    hint: AppStrings.hintTitleServerUrl,
                    required: true,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _aesKeyController,
                    label: AppStrings.labelAesKey,
                    hint: AppStrings.hintAesKey,
                    required: true,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _aesIvController,
                    label: AppStrings.labelAesIv,
                    hint: AppStrings.hintAesIv,
                    required: true,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _clientIdController,
                    label: AppStrings.labelClientId,
                    hint: AppStrings.hintClientId,
                    required: true,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection(theme, AppStrings.optional, [
                  _buildField(
                    controller: _regionIdController,
                    label: AppStrings.labelRegionId,
                    hint: AppStrings.hintRegionId,
                    required: false,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _placeIdController,
                    label: AppStrings.labelPlaceId,
                    hint: AppStrings.hintPlaceId,
                    required: false,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _obfuscateController,
                    label: AppStrings.labelObfuscateParam,
                    hint: AppStrings.hintObfuscateParam,
                    required: false,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _apiVersionController,
                    label: AppStrings.labelApiVersion,
                    hint: AppStrings.hintApiVersion,
                    required: false,
                  ),
                ]),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text(AppStrings.save),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Card(
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
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool required,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? AppStrings.fieldRequired(label) : null
          : null,
    );
  }
}

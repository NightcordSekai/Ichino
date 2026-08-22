import 'package:flutter/material.dart';

import '../config/responsive.dart';
import '../config/strings.dart';
import '../config/title_server_config.dart';
import 'config_export_import_page.dart';

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
  final _regionIdController = TextEditingController();
  final _placeIdController = TextEditingController();
  final _obfuscateController = TextEditingController();
  final _apiVersionController = TextEditingController();
  final _regionNameController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _keychipIdController = TextEditingController();
  final _aimeUrlController = TextEditingController();
  final _aimeSaltController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
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
      _regionNameController.text = config.regionName;
      _placeNameController.text = config.placeName;
      _keychipIdController.text = config.keychipId;
      _aimeUrlController.text = config.aimeUrl;
      _aimeSaltController.text = config.aimeSalt;
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
    _regionNameController.dispose();
    _placeNameController.dispose();
    _keychipIdController.dispose();
    _aimeUrlController.dispose();
    _aimeSaltController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await TitleServerConfigHolder().update(TitleServerConfig(
      titleServerUrl: _urlController.text.trim(),
      aesKey: _aesKeyController.text.trim(),
      aesIv: _aesIvController.text.trim(),
      clientId: _clientIdController.text.trim(),
      regionId: int.tryParse(_regionIdController.text.trim()) ?? 0,
      placeId: int.tryParse(_placeIdController.text.trim()) ?? 0,
      obfuscateParam: _obfuscateController.text.trim(),
      apiVersion: _apiVersionController.text.trim(),
      regionName: _regionNameController.text.trim(),
      placeName: _placeNameController.text.trim(),
      keychipId: _keychipIdController.text.trim(),
      aimeUrl: _aimeUrlController.text.trim(),
      aimeSalt: _aimeSaltController.text.trim(),
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
          constraints: BoxConstraints(maxWidth: responsiveMaxWidth(context)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(theme, AppStrings.titleServerSection, [
                  _buildField(controller: _urlController, label: AppStrings.labelTitleServerUrl),
                  const SizedBox(height: 14),
                  _buildField(controller: _aesKeyController, label: AppStrings.labelAesKey),
                  const SizedBox(height: 14),
                  _buildField(controller: _aesIvController, label: AppStrings.labelAesIv),
                  const SizedBox(height: 14),
                  _buildField(controller: _clientIdController, label: AppStrings.labelClientId),
                  const SizedBox(height: 14),
                  _buildField(controller: _obfuscateController, label: AppStrings.labelObfuscateParam),
                  const SizedBox(height: 14),
                  _buildField(controller: _apiVersionController, label: AppStrings.labelApiVersion),
                ]),
                const SizedBox(height: 24),
                _buildSection(theme, AppStrings.machineSettings, [
                  _buildField(controller: _regionIdController, label: AppStrings.labelRegionId),
                  const SizedBox(height: 14),
                  _buildField(controller: _regionNameController, label: AppStrings.labelRegionName),
                  const SizedBox(height: 14),
                  _buildField(controller: _placeIdController, label: AppStrings.labelPlaceId),
                  const SizedBox(height: 14),
                  _buildField(controller: _placeNameController, label: AppStrings.labelPlaceName),
                ]),
                const SizedBox(height: 24),
                _buildSection(theme, AppStrings.authServerSettings, [
                  _buildField(controller: _keychipIdController, label: AppStrings.labelKeychipId),
                  const SizedBox(height: 14),
                  _buildField(controller: _aimeUrlController, label: AppStrings.labelAimeUrl),
                  const SizedBox(height: 14),
                  _buildField(controller: _aimeSaltController, label: AppStrings.labelAimeSalt),
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ConfigExportImportPage()),
                    );
                    if (mounted) {
                      _loadConfig();
                    }
                  },
                  icon: const Icon(Icons.import_export, size: 20),
                  label: const Text(AppStrings.configExportImport),
                  style: OutlinedButton.styleFrom(
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
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.fieldRequired(label) : null,
    );
  }
}

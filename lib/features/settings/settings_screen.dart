import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../app/app_state.dart';
import '../../core/services/admin_guard.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          _heading('Business'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(state.business?['name']?.toString() ?? 'Business'),
              subtitle: Text(state.business?['owner_name']?.toString() ?? ''),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editBusiness(state),
            ),
          ),
          _heading('Appearance and currency'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Currency'),
                  subtitle: Text(
                    '${state.currencyCode} — ${state.settings['currency_symbol'] ?? 'Rs.'}',
                  ),
                  trailing: DropdownButton<String>(
                    value: state.currencyCode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'LKR', child: Text('LKR')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                      DropdownMenuItem(value: 'INR', child: Text('INR')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      const symbols = {
                        'LKR': 'Rs.',
                        'USD': r'$',
                        'EUR': '€',
                        'GBP': '£',
                        'INR': '₹',
                      };
                      await state.setSetting('currency_code', value);
                      await state.setSetting(
                        'currency_symbol',
                        symbols[value]!,
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Theme'),
                  trailing: DropdownButton<String>(
                    value: state.settings['theme_mode'] ?? 'system',
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('System')),
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    ],
                    onChanged: (value) {
                      if (value != null) state.setSetting('theme_mode', value);
                    },
                  ),
                ),
              ],
            ),
          ),
          _heading('Sales'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.remove_shopping_cart_outlined),
                  title: const Text('Allow negative stock'),
                  subtitle: const Text(
                    'Permit sales when available stock is insufficient',
                  ),
                  value: state.settings['allow_negative_stock'] == 'true',
                  onChanged:
                      (value) => state.setSetting(
                        'allow_negative_stock',
                        value.toString(),
                      ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.language),
                  title: const Text('Online product lookup'),
                  subtitle: const Text('Used only when a barcode is not local'),
                  value: state.settings['online_lookup'] != 'false',
                  onChanged:
                      (value) =>
                          state.setSetting('online_lookup', value.toString()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Bill footer'),
                  subtitle: Text(state.settings['bill_footer'] ?? ''),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap:
                      () => _editSetting(
                        state,
                        key: 'bill_footer',
                        title: 'Bill footer',
                        value: state.settings['bill_footer'] ?? '',
                      ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: const Text('Bill prefix'),
                  subtitle: Text(state.settings['bill_prefix'] ?? 'EP'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap:
                      () => _editSetting(
                        state,
                        key: 'bill_prefix',
                        title: 'Bill prefix',
                        value: state.settings['bill_prefix'] ?? 'EP',
                      ),
                ),
              ],
            ),
          ),
          _heading('Security'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Change admin PIN'),
                  subtitle: const Text(
                    'Protect prices, stock, settings and reports',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePin(state),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric authentication'),
                  subtitle: const Text(
                    'Use fingerprint or face unlock when available',
                  ),
                  value: state.settings['biometric_enabled'] == 'true',
                  onChanged: (value) async {
                    if (value) {
                      final auth = LocalAuthentication();
                      if (!await auth.canCheckBiometrics) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No biometric authentication is configured.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    await state.setSetting(
                      'biometric_enabled',
                      value.toString(),
                    );
                  },
                ),
              ],
            ),
          ),
          _heading('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Upload or share complete backup'),
                  subtitle: const Text(
                    'Includes configuration, products, stock, sales and settings',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final file = await state.database.backupDatabase();
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file.path)],
                        text:
                            'EasyPOS 1.4 complete backup. Save this file to Google Drive, OneDrive or another safe location.',
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Download or restore backup'),
                  subtitle: const Text(
                    'Move all EasyPOS data to this device from a backup file',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    if (!await AdminGuard.authorize(
                      context,
                      action: 'restore application data',
                    )) {
                      return;
                    }
                    final selection = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['db'],
                    );
                    final path = selection?.files.single.path;
                    if (path == null || !context.mounted) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Restore backup?'),
                            content: const Text(
                              'Current local data will be replaced. A fresh backup is created first.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Restore'),
                              ),
                            ],
                          ),
                    );
                    if (confirm != true) return;
                    await state.database.backupDatabase();
                    await state.database.restoreDatabase(File(path));
                    await state.initialize();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup restored.')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Reset application data'),
                  subtitle: const Text(
                    'Delete all products, sales and settings',
                  ),
                  onTap: () async {
                    if (!await AdminGuard.authorize(
                      context,
                      action: 'reset application data',
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                    final confirmation = TextEditingController();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Reset EasyPOS?'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'A backup will be created first. Type RESET to continue.',
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: confirmation,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'RESET',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed:
                                    () => Navigator.pop(
                                      context,
                                      confirmation.text == 'RESET',
                                    ),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                    );
                    confirmation.dispose();
                    if (confirmed != true) return;
                    await state.database.backupDatabase();
                    await state.database.resetDatabase();
                    await state.initialize();
                  },
                ),
              ],
            ),
          ),
          _heading('About'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.point_of_sale),
              title: Text('EasyPOS 1.4.0'),
              subtitle: Text(
                'Lightweight offline point of sale\nDeveloped by HamdhyTech',
              ),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Future<void> _editBusiness(AppState state) async {
    final name = TextEditingController(
      text: state.business?['name']?.toString(),
    );
    final owner = TextEditingController(
      text: state.business?['owner_name']?.toString(),
    );
    final phone = TextEditingController(
      text: state.business?['phone']?.toString(),
    );
    final address = TextEditingController(
      text: state.business?['address']?.toString(),
    );
    final save = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Business profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: owner,
                    decoration: const InputDecoration(labelText: 'Owner name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (save == true) {
      await state.saveBusiness({
        'name': name.text.trim(),
        'owner_name': owner.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'admin_pin_hash': state.business?['admin_pin_hash'],
      });
    }
    name.dispose();
    owner.dispose();
    phone.dispose();
    address.dispose();
  }

  Future<void> _editSetting(
    AppState state, {
    required String key,
    required String title,
    required String value,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      await state.setSetting(key, result);
    }
  }

  Future<void> _changePin(AppState state) async {
    if (!await AdminGuard.authorize(context, action: 'change the admin PIN')) {
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('New admin PIN'),
            content: TextField(
              controller: controller,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '4-digit PIN',
                hintText: 'Leave blank to remove',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.isEmpty ||
                      RegExp(r'^\d{4}$').hasMatch(controller.text)) {
                    Navigator.pop(context, controller.text);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (result != null) {
      await state.saveBusiness({
        'name': state.business?['name'],
        'owner_name': state.business?['owner_name'],
        'phone': state.business?['phone'],
        'address': state.business?['address'],
        'admin_pin_hash': result.isEmpty ? null : AdminGuard.hashPin(result),
      });
    }
    controller.dispose();
  }
}

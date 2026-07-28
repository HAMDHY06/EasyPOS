import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../core/services/admin_guard.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _pin = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_business, _owner, _phone, _address, _pin]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<AppState>().completeSetup({
      'name': _business.text.trim(),
      'owner_name': _owner.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'admin_pin_hash':
          _pin.text.isEmpty ? null : AdminGuard.hashPin(_pin.text),
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/easypos_logo.png',
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'EasyPOS',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Text('by HamdhyTech', textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _business,
                      decoration: const InputDecoration(
                        labelText: 'Business name',
                        prefixIcon: Icon(Icons.storefront),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _owner,
                      decoration: const InputDecoration(
                        labelText: 'Owner name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: 'LKR',
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'LKR',
                          child: Text('LKR — Rs.'),
                        ),
                      ],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Admin PIN (optional)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator:
                          (value) =>
                              value != null &&
                                      value.isNotEmpty &&
                                      value.length != 4
                                  ? 'Enter exactly 4 digits'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon:
                          _saving
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.arrow_forward),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Start using EasyPOS'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your data stays offline and can be transferred with a complete backup.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

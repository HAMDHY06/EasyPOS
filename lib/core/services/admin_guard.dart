import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../app/app_state.dart';

class AdminGuard {
  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('EasyPOS:$pin')).toString();

  static Future<bool> authorize(
    BuildContext context, {
    String action = 'continue',
  }) async {
    final saved =
        context.read<AppState>().business?['admin_pin_hash']?.toString();
    if (saved == null || saved.isEmpty) return true;
    final state = context.read<AppState>();
    if (state.settings['biometric_enabled'] == 'true') {
      try {
        final auth = LocalAuthentication();
        if (await auth.canCheckBiometrics &&
            await auth.authenticate(
              localizedReason: 'Authenticate to $action',
              options: const AuthenticationOptions(biometricOnly: true),
            )) {
          return true;
        }
      } catch (_) {
        // PIN remains available when biometrics are unavailable.
      }
    }
    if (!context.mounted) return false;
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminPinDialog(savedHash: saved, action: action),
    );
    return allowed ?? false;
  }
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog({required this.savedHash, required this.action});

  final String savedHash;
  final String action;

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (AdminGuard.hashPin(_controller.text) == widget.savedHash) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin PIN required'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Enter PIN to ${widget.action}',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Unlock')),
      ],
    );
  }
}

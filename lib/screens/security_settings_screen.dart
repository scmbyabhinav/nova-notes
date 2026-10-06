
import 'package:flutter/material.dart';
import '../core/widgets/orah_asset_icon.dart';

import '../core/services/nova_security_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key, this.returnToVault = false});

  final bool returnToVault;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _security = NovaSecurityService();

  bool _hasPin = false;
  bool _hasVaultPin = false;
  bool _appLock = false;
  bool _biometric = false;
  bool _biometricAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _security.hasPin(),
      _security.hasVaultPin(),
      _security.isAppLockEnabled(),
      _security.isBiometricEnabled(),
      _security.canUseBiometrics(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasPin = values[0] as bool;
      _hasVaultPin = values[1] as bool;
      _appLock = values[2] as bool;
      _biometric = values[3] as bool;
      _biometricAvailable = values[4] as bool;
      _loading = false;
    });
  }

  Future<void> _setPin() async {
    final first = await _pinDialog('Create PIN');
    if (first == null) return;
    final second = await _pinDialog('Confirm PIN');
    if (second == null) return;

    if (first != second) {
      _message('PINs do not match.');
      return;
    }

    try {
      await _security.setPin(first);
      await _security.setAppLockEnabled(true);
      if (!mounted) return;
      setState(() {
        _hasPin = true;
        _appLock = true;
      });
      _message('PIN created. App lock is on.');
    } catch (e) {
      _message(e.toString().replaceFirst('FormatException: ', ''));
    }
  }

  Future<void> _setVaultPin() async {
    if (_hasVaultPin) {
      final current = await _pinDialog('Verify current Vault PIN');
      if (current == null || !await _security.verifyVaultPin(current)) {
        _message('Incorrect Vault PIN.');
        return;
      }
    }
    final first = await _pinDialog(_hasVaultPin ? 'Create new Vault PIN' : 'Create Vault PIN');
    if (first == null) return;
    final second = await _pinDialog('Confirm Vault PIN');
    if (second == null) return;
    if (first != second) {
      _message('Vault PINs do not match.');
      return;
    }
    try {
      await _security.setVaultPin(first);
      if (!mounted) return;
      setState(() => _hasVaultPin = true);
      _message('Vault PIN saved.');
      if (widget.returnToVault) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      _message(e.toString().replaceFirst('FormatException: ', ''));
    }
  }

  Future<void> _removePin() async {
    final pin = await _pinDialog('Enter current PIN');
    if (pin == null) return;
    if (!await _security.verifyPin(pin)) {
      _message('Incorrect PIN.');
      return;
    }
    await _security.removePin();
    if (!mounted) return;
    setState(() {
      _hasPin = false;
      _appLock = false;
      _biometric = false;
    });
    _message('PIN and app lock disabled.');
  }

  Future<void> _toggleAppLock(bool value) async {
    if (!_hasPin && value) {
      await _setPin();
      return;
    }
    if (!_hasPin) return;
    await _security.setAppLockEnabled(value);
    if (!mounted) return;
    setState(() => _appLock = value);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!value) {
      await _security.setBiometricEnabled(false);
      if (mounted) setState(() => _biometric = false);
      return;
    }

    if (!_hasPin) {
      await _setPin();
      if (!_hasPin) return;
    }

    final ok = await _security.authenticateBiometric();
    if (!ok) {
      _message('Biometric verification was not completed.');
      return;
    }
    await _security.setBiometricEnabled(true);
    if (mounted) setState(() => _biometric = true);
  }

  Future<String?> _pinDialog(String title) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'PIN',
              hintText: '4–8 digits',
            ),
            validator: (value) {
              if (value == null || !RegExp(r'^\d{4,8}$').hasMatch(value)) {
                return 'Enter 4–8 digits';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Security & Privacy')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('App lock'),
            subtitle: Text(
              _hasPin
                  ? 'Require your PIN when ORAH is locked'
                  : 'Create a PIN to protect ORAH',
            ),
            value: _appLock,
            onChanged: _toggleAppLock,
          ),
          if (_hasPin)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change PIN'),
              subtitle: const Text('Replace your current ORAH PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setPin,
            ),
          if (_hasPin)
            ListTile(
              leading: const OrahAssetIcon('trash'),
              title: const Text('Remove PIN'),
              subtitle: const Text('Turn off PIN protection'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _removePin,
            ),
          if (_biometricAvailable)
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biometric unlock'),
              subtitle: const Text('Use fingerprint or device biometrics'),
              value: _biometric,
              onChanged: _toggleBiometric,
            ),
          const Divider(height: 28),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: Text(_hasVaultPin ? 'Change Vault PIN' : 'Create Vault PIN'),
            subtitle: const Text('Military-Grade Vault • No recovery if the PIN is forgotten.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _setVaultPin,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Military-Grade Vault: your locked notes stay protected on this device. There is no recovery if the Vault PIN is forgotten.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Local-first privacy'),
            subtitle: Text(
              'ORAH does not require an account or cloud sync for your notes.',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Text(
              'Security note: PIN credentials are stored in Android/iOS '
              'secure storage. Sensitive note content remains local. '
              'Full encrypted note-vault storage will be added before '
              'ORAH claims end-to-end encrypted content.',
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../l10n/app_localizations.dart';

import '../core/services/nova_security_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _security = NovaSecurityService();

  bool _hasPin = false;
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
      _security.isAppLockEnabled(),
      _security.isBiometricEnabled(),
      _security.canUseBiometrics(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasPin = values[0] as bool;
      _appLock = values[1] as bool;
      _biometric = values[2] as bool;
      _biometricAvailable = values[3] as bool;
      _loading = false;
    });
  }

  Future<void> _setPin() async {
    final l10n = AppLocalizations.of(context)!;
    final first = await _pinDialog(l10n.securityCreatePin);
    if (first == null) return;
    final second = await _pinDialog(l10n.securityConfirmPin);
    if (second == null) return;

    if (first != second) {
      _message(l10n.securityPinMismatch);
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
      _message(l10n.securityPinCreated);
    } catch (e) {
      _message(l10n.securityPinActionFailed(e.toString().replaceFirst('FormatException: ', '')));
    }
  }

  Future<void> _removePin() async {
    final l10n = AppLocalizations.of(context)!;
    final pin = await _pinDialog(l10n.securityEnterCurrentPin);
    if (pin == null) return;
    if (!await _security.verifyPin(pin)) {
      _message(l10n.incorrectPin);
      return;
    }
    await _security.removePin();
    if (!mounted) return;
    setState(() {
      _hasPin = false;
      _appLock = false;
      _biometric = false;
    });
    _message(l10n.securityPinDisabled);
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
    final l10n = AppLocalizations.of(context)!;
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
      _message(l10n.securityBiometricNotCompleted);
      return;
    }
    await _security.setBiometricEnabled(true);
    if (mounted) setState(() => _biometric = true);
  }

  Future<String?> _pinDialog(String title) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;

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
            decoration: InputDecoration(
              labelText: l10n.pin,
              hintText: l10n.securityPinDigitsHint,
            ),
            validator: (value) {
              if (value == null || !RegExp(r'^\d{4,8}$').hasMatch(value)) {
                return l10n.securityEnterDigits;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text);
              }
            },
            child: Text(l10n.continueLabel),
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
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityAndPrivacy)),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.lock_outline),
            title: Text(l10n.securityAppLock),
            subtitle: Text(
              _hasPin
                  ? l10n.securityRequirePin
                  : l10n.securityCreatePinToProtect,
            ),
            value: _appLock,
            onChanged: _toggleAppLock,
          ),
          if (_hasPin)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: Text(l10n.securityChangePin),
              subtitle: Text(l10n.securityReplacePinSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setPin,
            ),
          if (_hasPin)
            ListTile(
              leading: const OrahAssetIcon('trash'),
              title: Text(l10n.securityRemovePin),
              subtitle: Text(l10n.securityTurnOffPinProtection),
              trailing: const Icon(Icons.chevron_right),
              onTap: _removePin,
            ),
          if (_biometricAvailable)
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l10n.securityBiometricUnlock),
              subtitle: Text(l10n.securityUseBiometrics),
              value: _biometric,
              onChanged: _toggleBiometric,
            ),
          const Divider(height: 28),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.securityLocalFirstPrivacy),
            subtitle: Text(l10n.securityLocalFirstDescription),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Text(l10n.securityStorageNote),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';

import '../core/services/nova_security_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _security = NovaSecurityService();
  final _controller = TextEditingController();

  bool _busy = false;
  String? _error;

  Future<void> _unlockWithPin() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await _security.verifyPin(_controller.text);
    if (!mounted) return;

    setState(() => _busy = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Incorrect PIN');
      _controller.clear();
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await _security.authenticateBiometric();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 38,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('NOVA is locked',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock to continue to your private notes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    onSubmitted: (_) => _unlockWithPin(),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _unlockWithPin,
                      child: const Text('Unlock'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<bool>(
                    future: _security.canUseBiometrics(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return OutlinedButton.icon(
                        onPressed: _busy ? null : _unlockWithBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Use biometrics'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/orah_user_profile_service.dart';

class OrahRegistrationScreen extends StatefulWidget {
  const OrahRegistrationScreen({super.key, required this.onRegistered});

  final ValueChanged<OrahUserProfile> onRegistered;

  @override
  State<OrahRegistrationScreen> createState() => _OrahRegistrationScreenState();
}

class _OrahRegistrationScreenState extends State<OrahRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await OrahUserProfileService.instance.register(
        fullName: _nameController.text,
        email: _emailController.text,
      );
      final profile = await OrahUserProfileService.instance.loadProfile();
      if (!mounted || profile == null) return;
      widget.onRegistered(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 38),
                    ),
                    const SizedBox(height: 24),
                    Text('Welcome to Orah', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Let’s personalize your space. Enter your name and email to get started.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        hintText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter your full name.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(r'^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$').hasMatch(email)
                            ? null
                            : 'Enter a valid email address.';
                      },
                      onFieldSubmitted: (_) => _register(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _register,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Register & continue'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your profile is stored securely on this device. Subscriber-list syncing requires a configured newsletter service.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
}

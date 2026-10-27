import 'package:flutter/material.dart';

import '../data/repositories/note_repository.dart';
import '../models/note.dart';
import '../services/prompt_service.dart';

class ReflectionPromptScreen extends StatefulWidget {
  const ReflectionPromptScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<ReflectionPromptScreen> createState() => _ReflectionPromptScreenState();
}

class _ReflectionPromptScreenState extends State<ReflectionPromptScreen> {
  final _controller = TextEditingController();
  late ReflectionPrompt _prompt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prompt = PromptService.instance.getPromptOfDay();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _newPrompt() {
    final service = PromptService.instance;
    var next = service.getRandomPrompt();
    var attempts = 0;
    while (next.text == _prompt.text && attempts < 5) {
      next = service.getRandomPrompt();
      attempts++;
    }
    setState(() => _prompt = next);
  }

  Future<void> _submit() async {
    final response = _controller.text.trim();
    if (response.isEmpty || _saving) return;

    setState(() => _saving = true);
    final created = DateTime.now();
    final note = Note(
      id: '${created.microsecondsSinceEpoch}_reflection',
      title: 'Daily Reflection',
      content: 'Prompt: ${_prompt.text}\n\n$response',
      type: NoteType.text,
      createdAt: created,
      updatedAt: created,
      tags: const ['Reflection'],
    );

    try {
      await widget.repository.saveNote(note);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reflection: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Reflection'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _newPrompt,
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('New prompt'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            _prompt.category.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _prompt.text,
            key: const ValueKey('reflection_prompt_text'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 8,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write whatever comes to mind…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving…' : 'Save reflection'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/repositories/note_repository.dart';
import '../models/note.dart';

class ReflectionPromptScreen extends StatefulWidget {
  const ReflectionPromptScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<ReflectionPromptScreen> createState() => _ReflectionPromptScreenState();
}

class _ReflectionPromptScreenState extends State<ReflectionPromptScreen> {
  static const _prompt = 'What is one thing you are grateful for today?';

  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final response = _controller.text.trim();
    if (response.isEmpty || _saving) return;

    setState(() => _saving = true);
    final created = DateTime.now();
    final note = Note(
      id: created.microsecondsSinceEpoch.toString() + '_reflection',
      title: 'Daily Reflection',
      content: response,
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
      appBar: AppBar(title: const Text('Daily Reflection')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            _prompt,
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

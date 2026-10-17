import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
      title: l10n.dailyReflection,
      content: '${l10n.reflectionPrompt}: ${_prompt.text}\n\n$response',
      type: NoteType.text,
      createdAt: created,
      updatedAt: created,
      tags: [l10n.reflectionPrompt],
    );

    try {
      await widget.repository.saveNote(note);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reflectionSaveError(e))),
      );
    }
  }

  String _localizedReflectionCategory(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Gratitude': return l10n.reflectionCategoryGratitude;
      case 'Mindfulness': return l10n.reflectionCategoryMindfulness;
      case 'Personal Growth': return l10n.reflectionCategoryPersonalGrowth;
      case 'Relationships': return l10n.reflectionCategoryRelationships;
      case 'Self-Compassion': return l10n.reflectionCategorySelfCompassion;
      case 'Clarity': return l10n.reflectionCategoryClarity;
      case 'Possibility': return l10n.reflectionCategoryPossibility;
      case 'Daily Review': return l10n.reflectionCategoryDailyReview;
      case 'Purpose & Values': return l10n.reflectionCategoryPurposeValues;
      case 'Resilience': return l10n.reflectionCategoryResilience;
      case 'Creativity & Curiosity': return l10n.reflectionCategoryCreativityCuriosity;
      case 'Rest & Renewal': return l10n.reflectionCategoryRestRenewal;
      default: return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyReflection),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _newPrompt,
            icon: const Icon(Icons.shuffle_rounded),
            label: Text(l10n.newPrompt),
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
            ${_localizedReflectionCategory(l10n, _prompt.category).toUpperCase()},
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
              hintText: l10n.reflectionWriteHint,
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? l10n.saving : l10n.saveReflection),
          ),
        ],
      ),
    );
  }
}

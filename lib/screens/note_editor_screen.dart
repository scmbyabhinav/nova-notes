import 'dart:async';
import '../core/widgets/nova_polish.dart';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import '../data/repositories/folder_repository_provider.dart';
import '../data/kanban/kanban_repository.dart';
import '../l10n/app_localizations.dart';
import 'kanban_screen.dart';
import '../data/repositories/local_note_repository.dart';
import '../data/repositories/note_repository.dart';
import '../models/folder.dart';
import '../models/note.dart';
import 'note_version_history_sheet.dart';
import 'organization_picker_screen.dart';
import 'export_note_sheet.dart';
import '../services/nova_attachment_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/orah_reminder_service.dart';
import '../services/orah_in_app_review_service.dart';
import '../services/orah_analytics_service.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../core/utils/lifecycle_timeout.dart';
import '../services/orah_ocr_service.dart';
import '../services/orah_entitlement_service.dart';
import '../core/services/nova_security_service.dart';
import 'package:intl/intl.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.repository,
    this.note,
    this.initialType = NoteType.text,
    this.initialTitle,
    this.initialContent,
    this.initialVaultFolderId,
    this.initialIsLocked = false,
    this.speechService,
    this.requestMicrophonePermission,
    this.autoStartVoice = false,
    this.autoOpenReminder = false,
    this.initialDueAt,
  });

  final NoteRepository repository;
  final Note? note;
  final NoteType initialType;
  final String? initialTitle;
  final String? initialContent;
  final String? initialVaultFolderId;
  final bool initialIsLocked;
  final VoiceSpeechService? speechService;
  final Future<PermissionStatus> Function()? requestMicrophonePermission;
  final bool autoStartVoice;
  final bool autoOpenReminder;
  final DateTime? initialDueAt;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _MarkdownTocSection {
  const _MarkdownTocSection({
    required this.content,
    this.title,
    this.level = 0,
    this.anchorKey,
  });

  final String content;
  final String? title;
  final int level;
  final GlobalKey? anchorKey;
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final Map<int, GlobalKey> _previewHeadingKeys = <int, GlobalKey>{};
  int _focusMinutes = 0;
  final FocusNode _contentFocus = FocusNode();
  final LifecycleTimeout _saveTimeout = LifecycleTimeout();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final TextEditingController _previewAppendController = TextEditingController();
  Timer? _saveTimer;
  late final DateTime _createdAt;
  late String _noteId;
  late NoteType _noteType;
  bool _saving = false;
  bool _saveFailed = false;
  bool _hasChanges = false;
  bool _hasHapticSaved = false;
  bool _reviewCounted = false;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  DateTime? _dueAt;
  String? _mood;
  String? _imagePath;
  int? _noteColor;
  String? _folderId;
  String? _vaultFolderId;
  List<String> _tags = const [];
  List<String> _linkedNoteIds = const [];
  List<String> _attachments = const [];
  List<ChecklistItem> _checklistItems = [];
  bool _previewMode = false;
  bool _showSlashCommandMenu = false;
  String _slashCommandQuery = '';
  int? _slashCommandStart;

  static const List<Map<String, String>> _slashCommands = [
    {'title': 'Heading 1', 'command': '/heading', 'description': 'Large section heading', 'insert': '# '},
    {'title': 'Heading 2', 'command': '/heading2', 'description': 'Medium section heading', 'insert': '## '},
    {'title': 'Heading 3', 'command': '/heading3', 'description': 'Small section heading', 'insert': '### '},
    {'title': 'To-do list', 'command': '/todo', 'description': 'Add an unchecked task', 'insert': '- [ ] '},
    {'title': 'Bulleted list', 'command': '/bullet', 'description': 'Start a bullet point', 'insert': '- '},
    {'title': 'Numbered list', 'command': '/numbered', 'description': 'Start a numbered list', 'insert': '1. '},
    {'title': 'Quote', 'command': '/quote', 'description': 'Add a quote block', 'insert': '> '},
    {'title': 'Code block', 'command': '/code', 'description': 'Insert a fenced code block', 'insert': '\u0060\u0060\u0060\n\n\u0060\u0060\u0060'},
    {'title': 'Divider', 'command': '/divider', 'description': 'Add a horizontal divider', 'insert': '---\n'},
  ];
  bool _isZenMode = false;
  bool _isCapturingNoteCard = false;
  bool _isLocked = false;
  bool _privateUnlocked = true;
  bool _unlocking = false;
  String? _lockedCiphertext;
  late final VoiceSpeechService _speechService;
  bool _speechInitializing = false;
  bool _isListening = false;
  bool _voiceProcessing = false;
  bool _voiceSessionActive = false;
  bool _voiceStopRequested = false;
  String _voiceBaseText = '';
  String _voiceTranscript = '';
  Timer? _voiceDurationTimer;
  int _voiceElapsedSeconds = 0;
  final ScreenshotController _noteCardScreenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _speechService = widget.speechService ?? SpeechToTextService();

    final existing = widget.note;
    _reviewCounted = existing != null;
    _focusMinutes = existing?.focusMinutes ?? 0;
    _noteId = existing?.id ?? _newId();
    _createdAt = existing?.createdAt ?? DateTime.now();
    _noteType = existing?.type ?? widget.initialType;

    final locked = existing?.isLocked ?? widget.initialIsLocked;
    _titleController = TextEditingController(
      text: locked ? '' : (existing?.title ?? widget.initialTitle ?? ''),
    );
    _contentController = TextEditingController(
      text: locked ? '' : (existing?.content ?? widget.initialContent ?? ''),
    );

    _isPinned = existing?.isPinned ?? false;
    _isFavorite = existing?.isFavorite ?? false;
    _isArchived = existing?.isArchived ?? false;
    _isLocked = locked;
    _privateUnlocked = !locked;
    if (locked) _lockedCiphertext = existing?.content;
    _dueAt = existing?.dueAt ?? widget.initialDueAt;
    _mood = existing?.mood;
    _imagePath = existing?.imagePath;
    _noteColor = existing?.color;
    _folderId = existing?.folderId;
    _vaultFolderId = existing?.vaultFolderId ?? widget.initialVaultFolderId;
    _tags = locked ? const [] : [...(existing?.tags ?? const [])];
    _linkedNoteIds = locked ? const [] : [...(existing?.linkedNoteIds ?? const [])];
    _attachments = [...(existing?.attachments ?? const [])];
    _checklistItems = locked ? [] : [...(existing?.checklistItems ?? const [])];
    if (!locked && _noteType == NoteType.checklist && _checklistItems.isEmpty && (existing?.content.trim().isNotEmpty ?? false)) _checklistItems = _parseChecklistContent(existing!.content);

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoStartVoice) _toggleVoiceInput();
      if (widget.autoOpenReminder) _setDueDate();
    });
  }

  String _formatVoiceDuration() {
    final minutes = (_voiceElapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_voiceElapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startVoiceDurationTimer() {
    _voiceDurationTimer?.cancel();
    _voiceElapsedSeconds = 0;
    _voiceDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isListening) {
        setState(() => _voiceElapsedSeconds++);
      }
    });
  }

  Future<void> _showMicrophonePermissionDialog({
    required bool permanentlyDenied,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.mic_off_rounded, size: 36),
        title: const Text('Microphone access needed'),
        content: Text(
          permanentlyDenied
              ? 'Orah Notes needs microphone access to transcribe your voice. You can enable this in Settings.'
              : 'Orah Notes needs microphone access to transcribe your voice. Please allow access, or enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await openAppSettings();
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_speechInitializing || _voiceProcessing) return;
    if (_isListening) {
      await _stopAndSaveVoiceInput();
      return;
    }

    setState(() => _speechInitializing = true);
    final permission = await (widget.requestMicrophonePermission?.call() ??
        Permission.microphone.request());
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() => _speechInitializing = false);
      await _showMicrophonePermissionDialog(
        permanentlyDenied: permission.isPermanentlyDenied,
      );
      return;
    }

    try {
      final available = await _speechService.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if ((status == 'done' || status == 'notListening') &&
              _voiceSessionActive &&
              !_voiceStopRequested) {
            unawaited(_handleUnexpectedVoiceStop());
          }
        },
        onError: (message) {
          if (!mounted) return;
          if (_voiceSessionActive && !_voiceStopRequested) {
            unawaited(_handleUnexpectedVoiceStop());
          } else {
            setState(() {
              _speechInitializing = false;
              _voiceProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Voice input unavailable: $message')),
            );
          }
        },
      );
      if (!mounted) return;
      if (!available) {
        setState(() => _speechInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice input is unavailable on this device.'),
          ),
        );
        return;
      }

      _voiceBaseText = _contentController.text;
      _voiceTranscript = '';
      _voiceStopRequested = false;
      _voiceSessionActive = true;
      _startVoiceDurationTimer();
      setState(() {
        _speechInitializing = false;
        _voiceProcessing = false;
        _isListening = true;
      });
      await _speechService.startListening(
        onResult: (transcript, isFinal) {
          if (!mounted || transcript.trim().isEmpty) return;
          _voiceTranscript = transcript.trim();
          final baseText = _voiceBaseText.trimRight();
          final separator = baseText.isEmpty ? '' : '\n';
          final nextText = '$baseText$separator$_voiceTranscript';
          _contentController.value = _contentController.value.copyWith(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
            composing: TextRange.empty,
          );
          if (isFinal) {
            _voiceBaseText = nextText;
            _voiceTranscript = '';
            _voiceSessionActive = false;
            _voiceStopRequested = true;
            _voiceDurationTimer?.cancel();
            if (_titleController.text.trim().isEmpty) {
              final firstLine = nextText
                  .split(RegExp(r'\r?\n'))
                  .map((line) => line.trim())
                  .firstWhere((line) => line.isNotEmpty, orElse: () => '');
              if (firstLine.isNotEmpty) {
                _titleController.text = firstLine.length > 80
                    ? '${firstLine.substring(0, 80)}…'
                    : firstLine;
              }
            }
            _hasChanges = true;
            _isListening = false;
            _voiceProcessing = false;
            unawaited(_save());
            if (mounted) setState(() {});
          }
        },
      );
    } catch (error) {
      if (!mounted) return;
      _voiceSessionActive = false;
      _voiceStopRequested = true;
      _voiceDurationTimer?.cancel();
      setState(() {
        _speechInitializing = false;
        _voiceProcessing = false;
        _isListening = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start voice capture: $error')),
      );
    }
  }

  Future<void> _stopAndSaveVoiceInput() async {
    if (!_isListening || _voiceProcessing) return;
    _voiceStopRequested = true;
    _voiceDurationTimer?.cancel();
    setState(() {
      _isListening = false;
      _voiceProcessing = true;
    });
    try {
      await _speechService.stopListening();
    } catch (_) {
      // The latest partial text is already in the editor and will still be saved.
    }
    if (!mounted) return;
    _voiceSessionActive = false;
    _voiceBaseText = _contentController.text;
    _voiceTranscript = '';
    _hasChanges = true;
    setState(() => _voiceProcessing = false);
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice text saved to note.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cancelVoiceInput() async {
    _voiceStopRequested = true;
    _voiceSessionActive = false;
    _voiceDurationTimer?.cancel();
    try {
      await _speechService.cancel();
    } catch (_) {
      // Discard should still restore the text from before this voice session.
    }
    if (!mounted) return;
    _contentController.value = TextEditingValue(
      text: _voiceBaseText,
      selection: TextSelection.collapsed(offset: _voiceBaseText.length),
    );
    _voiceTranscript = '';
    setState(() {
      _speechInitializing = false;
      _voiceProcessing = false;
      _isListening = false;
    });
  }

  Future<void> _retryVoiceInput() async {
    final baseline = _voiceBaseText;
    await _cancelVoiceInput();
    if (!mounted) return;
    _contentController.value = TextEditingValue(
      text: baseline,
      selection: TextSelection.collapsed(offset: baseline.length),
    );
    await _toggleVoiceInput();
  }

  Future<void> _handleUnexpectedVoiceStop() async {
    if (!_voiceSessionActive || !mounted) return;
    _voiceSessionActive = false;
    _voiceStopRequested = true;
    _voiceDurationTimer?.cancel();
    final hasPartialText = _voiceTranscript.trim().isNotEmpty;
    _voiceBaseText = _contentController.text;
    _voiceTranscript = '';
    setState(() {
      _speechInitializing = false;
      _voiceProcessing = false;
      _isListening = false;
    });
    if (!hasPartialText) return;
    _hasChanges = true;
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording stopped. Partial text saved.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  List<ChecklistItem> _parseChecklistContent(String content) {
    return content.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).map((line) {
      final trimmed = line.trim();
      final done = trimmed.startsWith('[x]') || trimmed.startsWith('[X]') || trimmed.startsWith('☑');
      final text = trimmed.replaceFirst(RegExp(r'^(?:\[[ xX]\]|☐|☑)\s*'), '').replaceFirst(RegExp(r'^[-*•]\s*'), '');
      return ChecklistItem(id: text.hashCode.toString(), text: text, isDone: done);
    }).toList();
  }

  String _checklistContent() => _checklistItems.map((item) => (item.isDone ? '[x] ' : '[ ] ') + item.text).join('\n');

  Future<void> _addChecklistItem() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add task'),
      content: TextField(controller: controller, autofocus: true, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'What needs to be done?')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add'))],
    ));
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    setState(() { _checklistItems = [..._checklistItems, ChecklistItem(id: _newId(), text: text.trim())]; _hasChanges = true; });
    await _save();
  }

  Future<void> _editChecklistItem(int index) async {
    final controller = TextEditingController(text: _checklistItems[index].text);
    final text = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Edit task'), content: TextField(controller: controller, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))],
    ));
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    setState(() { _checklistItems[index] = _checklistItems[index].copyWith(text: text.trim()); _hasChanges = true; });
    await _save();
  }

  Future<void> _toggleChecklistItem(int index, bool value) async {
    setState(() { _checklistItems[index] = _checklistItems[index].copyWith(isDone: value); _hasChanges = true; });
    await _save();
  }

  Future<void> _setChecklistItemReminder(int index) async {
    final item = _checklistItems[index];
    final now = DateTime.now();
    final initial = item.dueAt ?? now.add(const Duration(hours: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(9999, 12, 31),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _checklistItems[index] = item.copyWith(
        dueAt: DateTime(picked.year, picked.month, picked.day, time.hour, time.minute),
      );
      _hasChanges = true;
    });
    await _save();
  }

  Future<void> _clearChecklistItemReminder(int index) async {
    final item = _checklistItems[index];
    await OrahReminderService.instance.cancel('checklist:${item.id}');
    if (!mounted) return;
    setState(() {
      _checklistItems[index] = item.copyWith(clearDueAt: true);
      _hasChanges = true;
    });
    await _save();
  }

  Future<void> _removeChecklistItem(int index) async {
    final removed = _checklistItems[index];
    await OrahReminderService.instance.cancel('checklist:${removed.id}');
    setState(() { _checklistItems.removeAt(index); _hasChanges = true; });
    await _save();
  }

  Future<void> _reorderChecklist(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _checklistItems.removeAt(oldIndex);
      _checklistItems.insert(newIndex, item);
      _hasChanges = true;
    });
    await _save();
  }

  Future<bool> _authenticatePrivateAccess() async {
    final security = NovaSecurityService();
    if (await security.canUseBiometrics() &&
        await security.authenticateBiometric()) {
      return true;
    }
    if (!await security.hasVaultPin() && !await security.hasPin() || !mounted) return false;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Vault PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(labelText: '4–8 digit PIN'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('Unlock')),
        ],
      ),
    );
    controller.dispose();
    if (pin == null) return false;
    if (await security.hasVaultPin() && await security.verifyVaultPin(pin)) return true;
    return security.verifyPin(pin);
  }

  Future<void> _unlockPrivateNote() async {
    if (!_isLocked || _unlocking || !mounted) return;
    setState(() => _unlocking = true);

    if (!await _authenticatePrivateAccess()) {
      if (mounted) {
        setState(() => _unlocking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed. Try biometrics or your Vault PIN.')),
        );
      }
      return;
    }

    try {
      final security = NovaSecurityService();
      final ciphertext = _lockedCiphertext;
      Map<String, dynamic>? payload;
      if (ciphertext != null && ciphertext.startsWith('vault:v1:')) {
        payload = jsonDecode(
          await security.decryptPrivatePayload(ciphertext),
        ) as Map<String, dynamic>;
      }

      final existing = widget.note;
      final title = payload?['title'] as String? ?? existing?.title ?? '';
      final content = payload?['content'] as String? ?? existing?.content ?? '';
      final tags = payload?['tags'] is List
          ? List<String>.from((payload?['tags'] as List).whereType<String>())
          : (existing?.tags ?? const <String>[]);
      final checklist = payload?['checklistItems'] is List
          ? (payload?['checklistItems'] as List)
              .whereType<Map>()
              .map((item) => ChecklistItem.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : (existing?.checklistItems ?? const <ChecklistItem>[]);

      _titleController.text = title;
      _contentController.text = content;
      _tags = tags;
      _checklistItems = checklist;

      if (!mounted) return;
      setState(() {
        _unlocking = false;
        _privateUnlocked = true;
        _hasChanges = ciphertext == null || !ciphertext.startsWith('vault:v1:');
      });
      if (_hasChanges) await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Private note could not be unlocked: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _ensureSecurityForLock() async {
    final security = NovaSecurityService();
    final hasPin = await security.hasVaultPin() || await security.hasPin();
    final biometricEnabled = await security.isBiometricEnabled();
    final biometricAvailable = biometricEnabled && await security.canUseBiometrics();
    if (hasPin || biometricAvailable) return false;
    if (!mounted) return false;

    final shouldSetup = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.shield_outlined,
          size: 42,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: const Text('Secure Your Vault'),
        content: const Text(
          'To lock this note, you need to set up a PIN or Biometric authentication first. '
          'This ensures only you can access it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Set Up Security'),
          ),
        ],
      ),
    );
    if (shouldSetup != true || !mounted) return false;

    final first = await _requestLockSetupPin('Create Vault PIN');
    if (first == null || !mounted) return false;
    final second = await _requestLockSetupPin('Confirm Vault PIN');
    if (second == null || !mounted) return false;
    if (first != second) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Your note was not locked.')),
      );
      return false;
    }

    try {
      await security.setPin(first);
      await security.setVaultPin(first);
      await security.setAppLockEnabled(true);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault PIN created. Securing your note now…')),
      );
      // Creating and confirming this PIN is the setup action authorizing this lock.
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('FormatException: ', ''))),
        );
      }
      return false;
    }
  }

  Future<String?> _requestLockSetupPin(String title) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            decoration: const InputDecoration(labelText: '4–8 digit PIN'),
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }

  Future<void> _lockNote() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _attachments.isEmpty && _checklistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some content before locking this note.')),
      );
      return;
    }

    final setupCompleted = await _ensureSecurityForLock();
    final security = NovaSecurityService();
    final hasPin = await security.hasPin();
    final biometricEnabled = await security.isBiometricEnabled();
    final biometricAvailable = biometricEnabled && await security.canUseBiometrics();
    if (!setupCompleted && !hasPin && !biometricAvailable) return;

    if (!setupCompleted && !await _authenticatePrivateAccess()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication was not completed. Note was not locked.')),
        );
      }
      return;
    }

    setState(() {
      _isLocked = true;
      _privateUnlocked = true;
      _hasChanges = true;
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note locked and moved to your Vault.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _unlockNotePermanently() async {
    if (!_isLocked || !_privateUnlocked || !mounted) return;
    setState(() {
      _isLocked = false;
      _privateUnlocked = true;
      _hasChanges = true;
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note unlocked and moved back to your notes.')),
    );
    Navigator.of(context).pop();
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';

  void _onChanged() {
    _updateSlashCommandMenu();
    _hasChanges = true;
    _save();
  }

  void _updateSlashCommandMenu() {
    if (!mounted || _isLocked || _previewMode || _noteType == NoteType.checklist) {
      if (_showSlashCommandMenu) {
        setState(() {
          _showSlashCommandMenu = false;
          _slashCommandQuery = '';
          _slashCommandStart = null;
        });
      }
      return;
    }
    final value = _contentController.value;
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_showSlashCommandMenu) {
        setState(() {
          _showSlashCommandMenu = false;
          _slashCommandQuery = '';
          _slashCommandStart = null;
        });
      }
      return;
    }
    final cursor = selection.baseOffset;
    final lineStart = value.text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0) + 1;
    final linePrefix = value.text.substring(lineStart, cursor);
    final match = RegExp(r'^(\s*)/([a-zA-Z-]*)$').firstMatch(linePrefix);
    if (match == null) {
      if (_showSlashCommandMenu) {
        setState(() {
          _showSlashCommandMenu = false;
          _slashCommandQuery = '';
          _slashCommandStart = null;
        });
      }
      return;
    }
    final query = match.group(2)!.toLowerCase();
    final start = lineStart + match.group(1)!.length;
    if (!_showSlashCommandMenu || _slashCommandQuery != query || _slashCommandStart != start) {
      setState(() {
        _showSlashCommandMenu = true;
        _slashCommandQuery = query;
        _slashCommandStart = start;
      });
    }
  }

  List<Map<String, String>> get _filteredSlashCommands {
    if (_slashCommandQuery.isEmpty) return _slashCommands;
    return _slashCommands.where((item) {
      return item['title']!.toLowerCase().contains(_slashCommandQuery) ||
          item['command']!.substring(1).contains(_slashCommandQuery) ||
          item['description']!.toLowerCase().contains(_slashCommandQuery);
    }).toList();
  }

  Widget _buildSlashCommandMenu(ThemeData theme) {
    final commands = _filteredSlashCommands;
    if (commands.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: commands.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
          itemBuilder: (context, index) {
            final item = commands[index];
            final icon = switch (item['title']) {
              'Heading 1' => Icons.title_rounded,
              'Heading 2' => Icons.format_size_rounded,
              'Heading 3' => Icons.text_fields_rounded,
              'To-do list' => Icons.check_box_outlined,
              'Bulleted list' => Icons.format_list_bulleted_rounded,
              'Numbered list' => Icons.format_list_numbered_rounded,
              'Quote' => Icons.format_quote_rounded,
              'Code block' => Icons.code_rounded,
              _ => Icons.horizontal_rule_rounded,
            };
            return ListTile(
              dense: true,
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(item['title']!),
              subtitle: Text(item['description']!),
              trailing: Text(item['command']!, style: theme.textTheme.labelSmall),
              onTap: () => _applySlashCommand(item),
            );
          },
        ),
      ),
    );
  }

  void _applySlashCommand(Map<String, String> command) {
    final value = _contentController.value;
    final selection = value.selection;
    final start = _slashCommandStart;
    if (start == null || !selection.isValid) return;
    final insertion = command['insert']!;
    final end = selection.baseOffset;
    final replacement = value.text.replaceRange(start, end, insertion);
    var caret = start + insertion.length;
    if (command['title'] == 'Code block') caret = start + 4;
    _contentController.value = TextEditingValue(
      text: replacement,
      selection: TextSelection.collapsed(offset: caret.clamp(0, replacement.length)),
      composing: TextRange.empty,
    );
    setState(() {
      _showSlashCommandMenu = false;
      _slashCommandQuery = '';
      _slashCommandStart = null;
      _hasChanges = true;
    });
    _contentFocus.requestFocus();
    _save();
  }
  Future<void> _save() async {
    if (!_hasChanges && widget.note != null) return;

    if (mounted) setState(() { _saving = true; _saveFailed = false; });

    try {
    final title = _titleController.text.trim();
    final content = _noteType == NoteType.checklist ? _checklistContent() : _contentController.text;

    if (title.isEmpty && content.trim().isEmpty && _mood == null && _attachments.isEmpty && _checklistItems.isEmpty) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    var storedTitle = title.isEmpty ? 'Untitled note' : title;
    var storedContent = content;
    var storedTags = _tags;
    var storedChecklistItems = _checklistItems;
    if (_isLocked) {
      final security = NovaSecurityService();
      storedContent = await security.encryptPrivatePayload(jsonEncode({
        'title': storedTitle,
        'content': content,
        'tags': _tags,
        'checklistItems': _checklistItems.map((item) => item.toMap()).toList(),
        'imagePath': _imagePath,
      }));
      storedTitle = '';
      storedTags = const [];
      storedChecklistItems = const [];
    }

    final note = widget.note == null
        ? Note(
            id: _noteId,
            title: storedTitle,
            content: storedContent,
            type: _noteType,
            createdAt: _createdAt,
            updatedAt: DateTime.now(),
            folderId: _folderId,
            vaultFolderId: _vaultFolderId,
            tags: storedTags,
            linkedNoteIds: _isLocked ? const [] : _linkedNoteIds,
            attachments: _attachments,
            checklistItems: storedChecklistItems,
            isPinned: _isPinned,
            isFavorite: _isFavorite,
            isArchived: _isArchived,
            isLocked: _isLocked,
            color: _noteColor,
            dueAt: _dueAt,
            mood: _mood,
            imagePath: _imagePath,
            focusMinutes: _focusMinutes,
          )
        : widget.note!.copyWith(
            title: storedTitle,
            content: storedContent,
            type: _noteType,
            updatedAt: DateTime.now(),
            folderId: _folderId,
            vaultFolderId: _vaultFolderId,
            tags: storedTags,
            linkedNoteIds: _isLocked ? const [] : _linkedNoteIds,
            attachments: _attachments,
            checklistItems: storedChecklistItems,
            isPinned: _isPinned,
            isFavorite: _isFavorite,
            isArchived: _isArchived,
            isLocked: _isLocked,
            color: _noteColor,
            dueAt: _dueAt,
            mood: _mood,
            imagePath: _imagePath,
            focusMinutes: _focusMinutes,
          );

    await _saveTimeout.run(widget.repository.saveNote(note), const Duration(seconds: 10));
    if (!_hasHapticSaved) {
      _hasHapticSaved = true;
      unawaited(HapticFeedback.lightImpact());
    }
    if (!_reviewCounted && widget.note == null) {
      _reviewCounted = true;
      unawaited(OrahAnalyticsService.instance.logNoteCreated(noteType: _noteType.name));
      unawaited(checkAndRequestReview());
    }
    // Explicitly re-publish the persisted snapshot after the awaited write.
    // This makes the save-to-list handoff deterministic even if a stream
    // emission raced with route navigation.
    if (widget.repository is LocalNoteRepository) {
      await _saveTimeout.run((widget.repository as LocalNoteRepository).refresh(), const Duration(seconds: 5));
    }
    try {
      for (final item in _checklistItems) {
        if (item.dueAt != null && !item.isDone) {
          await OrahReminderService.instance.schedule(noteId: 'checklist:${item.id}', title: item.text, when: item.dueAt!, payloadNoteId: _noteId);
        } else {
          await OrahReminderService.instance.cancel('checklist:${item.id}');
        }
      }
      if (_dueAt != null) {
        await OrahReminderService.instance.schedule(noteId: _noteId, title: note.title, when: _dueAt!);
      } else {
        await OrahReminderService.instance.cancel(_noteId);
      }
    } catch (_) {
      // Reminder plugins may be unavailable in widget tests; note persistence must still succeed.
    }
    _hasChanges = false;

    if (mounted) setState(() => _saving = false);
    } catch (error, stackTrace) {
      debugPrint('ORAH note save failed: $error\\n$stackTrace');
      _hasChanges = true;
      _saveFailed = true;
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note could not be saved. Your text is still open here. Check storage and tap Save again.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showVersionHistory() async {
    if (_isLocked || widget.repository is! LocalNoteRepository) return;
    await _save();
    if (!mounted || _saveFailed) return;
    final restored = await showModalBottomSheet<Note>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NoteVersionHistorySheet(
        repository: widget.repository as LocalNoteRepository,
        noteId: _noteId,
      ),
    );
    if (restored == null || !mounted) return;
    setState(() {
      _titleController.text = restored.title;
      _contentController.text = restored.content;
      _noteType = restored.type;
      _tags = [...restored.tags];
      _attachments = [...restored.attachments];
      _checklistItems = [...restored.checklistItems];
      _imagePath = restored.imagePath;
      _folderId = restored.folderId;
      _vaultFolderId = restored.vaultFolderId;
      _isPinned = restored.isPinned;
      _isFavorite = restored.isFavorite;
      _isArchived = restored.isArchived;
      _noteColor = restored.color;
      _dueAt = restored.dueAt;
      _mood = restored.mood;
      _hasChanges = true;
    });
    await _save();
  }

  Future<void> _close() async {
    _saveTimer?.cancel();
    await _save();

    if (!mounted || _saveFailed) return;
    Navigator.of(context).pop();
  }

  Future<List<NoteFolder>> _folders() async {
    final repository = await FolderRepositoryProvider.instance();
    return repository.getFolders();
  }

  Future<void> _organize() async {
    await _save();
    final folders = await _folders();

    if (!mounted) return;

    final result = await Navigator.of(context).push<OrganizationSelection>(
      MaterialPageRoute(
        builder: (_) => OrganizationPickerScreen(
          folders: folders,
          selectedFolderId: _folderId,
          selectedTags: _tags,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _folderId = result.folderId;
      _tags = result.tags;
      _hasChanges = true;
    });

    await _save();
  }

  Future<void> _scanTextFromImage() async {
    // OCR is free and available to every Orah user.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final text = await OrahOcrService.instance.extractText(File(picked.path));
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No readable text found.')));
        return;
      }
      final current = _contentController.text.trim();
      final combined = current.isEmpty ? text : '$current\n\n$text';
      _contentController.value = TextEditingValue(
        text: combined,
        selection: TextSelection.collapsed(offset: combined.length),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text extracted from image.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read text from that image.')));
    }
  }

  Future<void> _setNoteColor(Color? color) async {
    setState(() {
      _noteColor = color?.value;
      _hasChanges = true;
    });
    await _save();
  }

  Future<void> _showNoteColorPicker() async {
    const colors = <Color?>[null, Color(0xFFFFF3C4), Color(0xFFDDF7E8), Color(0xFFDCEBFF), Color(0xFFF1DFFF), Color(0xFFFFE0D2)];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final color in colors)
                InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setNoteColor(color);
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color ?? Theme.of(sheetContext).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _noteColor == color?.value ? Theme.of(sheetContext).colorScheme.primary : Theme.of(sheetContext).colorScheme.outlineVariant, width: 2),
                    ),
                    child: color == null ? const Icon(Icons.format_color_reset_outlined) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setDueDate() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(hours: 1));
    final picked = await showDatePicker(context: context, initialDate: initial.isBefore(now) ? now : initial, firstDate: now, lastDate: DateTime(9999, 12, 31));
    if (picked == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() { _dueAt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute); _hasChanges = true; });
    await _save();
  }

  Future<void> _clearDueDate() async { setState(() { _dueAt = null; _hasChanges = true; }); await _save(); }

  Future<void> _showTemplates() async {
    final templates = <String, List<String>>{'Meeting notes':['Agenda','Decisions','Action items'],'Daily plan':['Top priority','Important','If time allows'],'Shopping list':['Milk','Vegetables','Household'],'Travel plan':['Dates','Bookings','Places to visit']};
    final choice = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [const ListTile(title: Text('Choose a template')), for (final entry in templates.entries) ListTile(leading: const Icon(Icons.description_outlined), title: Text(entry.key), subtitle: Text(entry.value.join(' • ')), onTap: () => Navigator.pop(context, entry.key))])));
    if (choice == null || !mounted) return;
    final hasContent = _titleController.text.trim().isNotEmpty || _contentController.text.trim().isNotEmpty || _checklistItems.isNotEmpty;
    if (hasContent) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace current note?'),
          content: const Text('This template will replace the current title and content.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Replace')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() { _titleController.text = choice; _contentController.text = templates[choice]!.map((item) => '- $item').join('\n'); _hasChanges = true; });
    await _save();
  }

  Future<void> _setFlag({
    bool? pinned,
    bool? favorite,
    bool? archived,
  }) async {
    setState(() {
      if (pinned != null) _isPinned = pinned;
      if (favorite != null) _isFavorite = favorite;
      if (archived != null) _isArchived = archived;
      _hasChanges = true;
    });

    await _save();
  }


  String _renderableContent() {
    if (_noteType != NoteType.checklist) return _contentController.text;
    return _checklistItems.map((item) => '- [' + (item.isDone ? 'x' : ' ') + '] ' + item.text).join('\n');
  }

  void _wrapSelection(String before, String after) {
    final value = _contentController.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final selected = selection.textInside(value.text);
    final replacement = before + selected + after;
    _contentController.value = value.replaced(selection, replacement);
    _contentController.selection =
        TextSelection.collapsed(offset: selection.start + replacement.length);
    _contentFocus.requestFocus();
  }

  void _insertPrefix(String prefix) {
    final value = _contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final lineStart = value.text.lastIndexOf('\n', start - 1) + 1;
    _contentController.value = value.replaced(
      TextSelection.collapsed(offset: lineStart),
      prefix,
    );
    _contentController.selection =
        TextSelection.collapsed(offset: start + prefix.length);
    _contentFocus.requestFocus();
  }

  Future<void> _insertLink() async {
    final url = await _textDialog('Insert link', 'https://example.com');
    if (url == null || url.isEmpty) return;
    final value = _contentController.value;
    final selected = value.selection.textInside(value.text);
    _contentController.value = value.replaced(
      value.selection,
      selected.isEmpty ? '[link](' + url + ')' : '[' + selected + '](' + url + ')',
    );
    _contentFocus.requestFocus();
  }

  Future<String?> _textDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Insert')),
        ],
      ),
    );
  }


  Future<void> _addImageToBody(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 92);
      if (picked == null) return;
      final path = await const NovaAttachmentService().importXFile(picked);
      if (!mounted) return;
      setState(() {
        if (!_attachments.contains(path)) _attachments = [..._attachments, path];
        _hasChanges = true;
      });
      await _insertImageIntoBody(path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not insert image into note body: $error')),
        );
      }
    }
  }

  Future<void> _addImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked == null) return;
      final path = await const NovaAttachmentService().importXFile(picked);
      setState(() {
        _attachments = [..._attachments, path];
        _hasChanges = true;
      });
      await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add image: $e')),
        );
      }
    }
  }

  Future<void> _scanDocumentToJpg() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document scanning is currently available on Android.')),
      );
      return;
    }
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock this note before adding a scanned document.')),
      );
      return;
    }

    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: 20,
        isGalleryImport: true,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final scannedImages = result.images ?? const <String>[];
      if (scannedImages.isEmpty) return;

      final imported = <String>[];
      for (final imagePath in scannedImages) {
        imported.add(await const NovaAttachmentService().importFile(imagePath));
      }
      if (imported.isEmpty || !mounted) return;

      setState(() {
        _attachments = [..._attachments, ...imported];
        _hasChanges = true;
      });
      await _save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imported.length == 1
                  ? 'Scanned document saved as JPG.'
                  : '${imported.length} scanned pages saved as JPG attachments.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not scan document: $error')),
        );
      }
    } finally {
      try {
        await scanner.close();
      } catch (_) {
        // The scanner may already have released its native resources.
      }
    }
  }

  Future<void> _addFiles() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result.isEmpty) return;
      final imported = <String>[];
      for (final file in result) {
        final path = file.path;
        if (path != null && path.isNotEmpty) {
          imported.add(await const NovaAttachmentService().importFile(path));
        } else {
          // file_picker v13 removed the public bytes property. Read on demand.
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            imported.add(await const NovaAttachmentService().importBytes(bytes, file.name));
          }
        }
      }
      if (imported.isEmpty) return;
      setState(() {
        _attachments = [..._attachments, ...imported];
        _hasChanges = true;
      });
      await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add files: $e')),
        );
      }
    }
  }

  Future<void> _removeAttachment(String path) async {
    await const NovaAttachmentService().delete(path);
    setState(() {
      _attachments = _attachments.where((item) => item != path).toList();
      _hasChanges = true;
    });
    await _save();
  }

  Future<void> _shareNoteCard() async {
    await _save();
    if (!mounted) return;

    try {
      // Temporarily rebuild the captured surface with a known light theme and
      // opaque background, then restore the user's theme immediately.
      setState(() => _isCapturingNoteCard = true);
      await WidgetsBinding.instance.endOfFrame;

      final bytes = await _noteCardScreenshotController.capture(pixelRatio: 2);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The note card could not be captured.');
      }

      if (mounted) setState(() => _isCapturingNoteCard = false);

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'orah-note-card.png',
          ),
        ],
        subject: 'Orah note card',
        text: 'Shared from Orah',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturingNoteCard = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share note card: $e')),
        );
      }
    }
  }

  Future<void> _shareAttachment(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    await Share.shareXFiles([XFile(path)], subject: p.basename(path));
  }

  Future<void> _renameAttachment(String path) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(path));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename attachment'),
        content: TextField(controller: controller, autofocus: true, textInputAction: TextInputAction.done),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final renamed = await const NovaAttachmentService().rename(path, name.trim());
      setState(() {
        _attachments = _attachments.map((item) => item == path ? renamed : item).toList();
        _hasChanges = true;
      });
      await _save();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not rename attachment: ' + e.toString())));
    }
  }

  Future<void> _showAttachmentDetails(String path) async {
    final file = File(path);
    if (!await file.exists() || !mounted) return;
    final bytes = await file.length();
    final stat = await file.stat();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.basename(path)),
        content: Text('Size: ' + _formatBytes(bytes) + '\nModified: ' + stat.modified.toLocal().toString()),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return bytes.toString() + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toStringAsFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
  }

  void _previewAttachment(String path) {
    final isImage = ['.jpg','.jpeg','.png','.webp','.gif','.heic'].contains(p.extension(path).toLowerCase());
    if (!isImage) {
      _shareAttachment(path);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(minScale: 0.5, maxScale: 4, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(File(path), fit: BoxFit.contain))),
            Positioned(top: 4, right: 4, child: IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
          ],
        ),
      ),
    );
  }

  Future<void> _insertImageIntoBody(String path) async {
    if (_isLocked || !File(path).existsSync()) return;
    final value = _contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final imageMarkdown = '![' + p.basename(path) + '](' + Uri.file(path).toString() + ' "width=320")';
    final prefix = start > 0 && value.text[start - 1] != '\n' ? '\n\n' : '';
    final suffix = end < value.text.length && value.text.substring(end).startsWith('\n') ? '' : '\n\n';
    _contentController.value = value.copyWith(
      text: value.text.replaceRange(start, end, prefix + imageMarkdown + suffix),
      selection: TextSelection.collapsed(offset: start + prefix.length + imageMarkdown.length + suffix.length),
      composing: TextRange.empty,
    );
    _hasChanges = true;
    if (mounted) setState(() => _previewMode = true);
    await _save();
  }

  void _showAttachmentActions(String path) {
    final isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic']
        .contains(p.extension(path).toLowerCase());
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (isImage)
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Insert image into note body'),
                subtitle: const Text('Place the image at the current cursor position'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _insertImageIntoBody(path);
                },
              ),
            ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Preview'), onTap: () { Navigator.pop(sheetContext); _previewAttachment(path); }),
            ListTile(leading: const OrahAssetIcon('share'), title: const Text('Share'), onTap: () { Navigator.pop(sheetContext); _shareAttachment(path); }),
            ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: const Text('Rename'), onTap: () { Navigator.pop(sheetContext); _renameAttachment(path); }),
            ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () { Navigator.pop(sheetContext); _showAttachmentDetails(path); }),
            ListTile(leading: const OrahAssetIcon('trash'), title: const Text('Remove from note'), onTap: () { Navigator.pop(sheetContext); _removeAttachment(path); }),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Choose image to insert into note body'),
              subtitle: const Text('Adds the image and opens a preview of the note body'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addImageToBody(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addImage(ImageSource.gallery);
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scan document (save as JPG)'),
                subtitle: const Text('Auto-detect edges, crop and enhance pages'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _scanDocumentToJpg();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Attach files'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addFiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (_isLocked && !await _authenticatePrivateAccess()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed. Note was not deleted.')),
        );
      }
      return;
    }
    for (final path in _attachments) {
      await const NovaAttachmentService().delete(path);
    }
    await widget.repository.deleteNote(_noteId);
    await HapticFeedback.mediumImpact();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _saveTimeout.dispose();
    _speechService.dispose();
    _voiceDurationTimer?.cancel();
    _saveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _previewAppendController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _manageLinkedNotes() async {
    if (_isLocked) return;
    final allNotes = await widget.repository.getNotes();
    if (!mounted) return;
    final candidates = allNotes.where((note) =>
      note.id != _noteId && !note.isTrashed && !note.isLocked
    ).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final selected = Set<String>.from(_linkedNoteIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Linked notes'),
          content: SizedBox(
            width: 440,
            child: candidates.isEmpty
              ? const Text('Create another note first, then you can link it here.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    const Text('Select notes related to this one. Links are saved with your note.'),
                    const SizedBox(height: 12),
                    for (final candidate in candidates)
                      CheckboxListTile(
                        value: selected.contains(candidate.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(candidate.title.trim().isEmpty ? 'Untitled note' : candidate.title),
                        subtitle: Text(candidate.content.trim().replaceAll(RegExp(r'\\s+'), ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selected.add(candidate.id);
                          } else {
                            selected.remove(candidate.id);
                          }
                        }),
                      ),
                  ],
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('Save links')),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _linkedNoteIds = result.toList();
      _hasChanges = true;
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${_linkedNoteIds.length} linked note(s).')),
    );
  }

  Future<void> _linkToKanban() async {
    if (_isLocked) return;
    final repo = await openKanbanRepository();
    if (!mounted) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text('Link this note to a Kanban item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.view_kanban_outlined),
            title: const Text('Kanban card'),
            subtitle: const Text('Connect this note to a task card'),
            onTap: () => Navigator.pop(sheetContext, 'card'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Kanban goal'),
            subtitle: const Text('Connect this note to a goal'),
            onTap: () => Navigator.pop(sheetContext, 'goal'),
          ),
        ]),
      ),
    );
    if (kind == null || !mounted) return;
    if (kind == 'card') {
      final cards = await repo.getCards();
      if (!mounted) return;
      final selected = await showDialog<KanbanCard>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Select Kanban card'),
          children: cards.isEmpty
              ? [const Padding(padding: EdgeInsets.all(20), child: Text('No Kanban cards available yet.'))]
              : cards.map((card) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, card),
                  child: Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                )).toList(),
        ),
      );
      if (selected == null || !mounted) return;
      await repo.addLink(sourceType: 'card', sourceId: selected.id, targetType: 'note', targetId: _noteId);
    } else {
      final goals = await repo.getGoals();
      if (!mounted) return;
      final selected = await showDialog<KanbanGoal>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Select Kanban goal'),
          children: goals.isEmpty
              ? [const Padding(padding: EdgeInsets.all(20), child: Text('No Kanban goals available yet.'))]
              : goals.map((goal) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, goal),
                  child: Text(goal.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                )).toList(),
        ),
      );
      if (selected == null || !mounted) return;
      await repo.addLink(sourceType: 'goal', sourceId: selected.id, targetType: 'note', targetId: _noteId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kanban link saved.')),
      );
    }
  }

  Future<void> _showKanbanBacklinks() async {
    final l = AppLocalizations.of(context)!;
    final repo = await openKanbanRepository();
    final links = await repo.database.query('links',
      where: 'deleted_at IS NULL AND ((target_type = ? AND target_id = ?) OR (source_type = ? AND source_id = ?))',
      whereArgs: ['note', _noteId, 'note', _noteId],
      orderBy: 'created_at DESC');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l.kanbanLinkedItems), leading: const Icon(Icons.view_kanban_outlined)),
          if (links.isEmpty) ListTile(title: Text(l.kanbanNoNotesToLink)),
          for (final link in links)
            ListTile(
              leading: Icon(link['source_type'] == 'goal' ? Icons.flag_outlined : Icons.view_kanban_outlined),
              title: Text(l.kanbanOpenLinkedItem),
              subtitle: Text(link['source_id'] as String),
              onTap: () async {
                final outbound = link['source_type'] == 'note' && link['source_id'] == _noteId;
                final type = (outbound ? link['target_type'] : link['source_type']) as String;
                final id = (outbound ? link['target_id'] : link['source_id']) as String;
                final exists = type == 'goal'
                  ? await repo.database.query('goals', where: 'id = ? AND deleted_at IS NULL AND archived_at IS NULL', whereArgs: [id], limit: 1)
                  : await repo.database.query('kanban_cards', where: 'id = ? AND deleted_at IS NULL AND archived_at IS NULL', whereArgs: [id], limit: 1);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (exists.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanUnavailable)));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => KanbanScreen(repository: repo, initialGoalId: type == 'goal' ? id : null)));
                }
              },
            ),
        ],
      )),
    );
  }

  Future<void> _appendPreviewText() async {
    final addition = _previewAppendController.text.trim();
    if (addition.isEmpty || _isLocked) return;
    final current = _contentController.text.trimRight();
    final next = current.isEmpty ? addition : '$current\n\n$addition';
    _contentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
      composing: TextRange.empty,
    );
    _previewAppendController.clear();
    _hasChanges = true;
    if (mounted) setState(() {});
    await _save();
  }

  Future<void> _updateInlineImageWidth(Uri uri, double width) async {
    final expression = RegExp(
      r'(!\[[^\]]*\]\(' + RegExp.escape(uri.toString()) + r') "width=\d+"\)',
    );
    final updated = _contentController.text.replaceAllMapped(
      expression,
      (match) => match.group(0)!.replaceFirst(
        RegExp(r'width=\d+'),
        'width=${width.round()}',
      ),
    );
    if (updated == _contentController.text) return;
    _contentController.value = _contentController.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
      composing: TextRange.empty,
    );
    _hasChanges = true;
    await _save();
  }

  Future<void> _updateInlineImageCaption(Uri uri, String caption) async {
    final expression = RegExp(
      r'!\[([^\]]*)\]\(' + RegExp.escape(uri.toString()) + r'(?: "width=(\d+)")?\)',
    );
    final escapedCaption = caption.replaceAll(']', r'\]');
    final updated = _contentController.text.replaceAllMapped(
      expression,
      (match) {
        final width = match.group(2) ?? '320';
        return '![' + escapedCaption + '](' + uri.toString() + ' "width=' + width + '")';
      },
    );
    if (updated == _contentController.text) return;
    _contentController.value = _contentController.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
      composing: TextRange.empty,
    );
    _hasChanges = true;
    await _save();
  }

  List<_MarkdownTocSection> _buildMarkdownSections(String markdown) {
    final sections = <_MarkdownTocSection>[];
    var currentLines = <String>[];
    String? currentTitle;
    var currentLevel = 0;
    GlobalKey? currentKey;
    var headingIndex = 0;

    void flush() {
      if (currentLines.isEmpty) return;
      sections.add(_MarkdownTocSection(
        content: currentLines.join('\n'),
        title: currentTitle,
        level: currentLevel,
        anchorKey: currentKey,
      ));
    }

    for (final line in markdown.split('\n')) {
      final trimmed = line.trimLeft();
      var level = 0;
      while (level < trimmed.length && level < 4 && trimmed[level] == '#') {
        level++;
      }
      final isHeading = level >= 1 &&
          level <= 3 &&
          trimmed.length > level &&
          trimmed[level].trim().isEmpty &&
          trimmed.substring(level).trim().isNotEmpty;
      if (isHeading) {
        flush();
        currentLines = <String>[line];
        var title = trimmed.substring(level).trim();
        while (title.endsWith('#')) {
          title = title.substring(0, title.length - 1).trimRight();
        }
        currentTitle = title;
        currentLevel = level;
        currentKey = _previewHeadingKeys.putIfAbsent(headingIndex, () => GlobalKey());
        headingIndex++;
      } else {
        currentLines.add(line);
      }
    }
    flush();
    return sections;
  }

  Widget _buildMarkdownBody(String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      imageBuilder: (uri, title, alt) {
        if (uri.scheme == 'file') {
          try {
            final file = File(uri.toFilePath());
            if (file.existsSync()) {
              final match = RegExp(r'width=(\d+)').firstMatch(title ?? '');
              final width = match == null ? 320.0 : double.parse(match.group(1)!);
              return _ResizableInlineImage(
                file: file,
                width: width,
                caption: alt ?? '',
                onWidthChanged: (nextWidth) => _updateInlineImageWidth(uri, nextWidth),
                onCaptionChanged: (caption) => _updateInlineImageCaption(uri, caption),
              );
            }
          } catch (_) {
            // Invalid local image URI: render the fallback below.
          }
          return const Text('Image unavailable');
        }
        return Image.network(
          uri.toString(),
          errorBuilder: (_, __, ___) => const Text('Image unavailable'),
        );
      },
    );
  }

  List<Widget> _buildPreviewMarkdownWidgets(ThemeData theme) {
    final markdown = _renderableContent();
    final sections = _buildMarkdownSections(markdown);
    final headings = sections.where((section) => section.title != null).toList();
    if (headings.length < 2) {
      return <Widget>[_buildMarkdownBody(markdown)];
    }

    final widgets = <Widget>[
      Card(
        margin: const EdgeInsets.only(bottom: 18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.list_alt_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Table of contents',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final heading in headings)
                Padding(
                  padding: EdgeInsets.only(left: (heading.level - 1) * 16.0),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      minimumSize: const Size.fromHeight(36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      final targetContext = heading.anchorKey?.currentContext;
                      if (targetContext != null) {
                        Scrollable.ensureVisible(
                          targetContext,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: 0.04,
                        );
                      }
                    },
                    child: Text(
                      heading.title!,
                      textAlign: TextAlign.left,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];

    for (final section in sections) {
      if (section.content.trim().isEmpty) continue;
      final body = _buildMarkdownBody(section.content);
      if (section.anchorKey != null) {
        widgets.add(KeyedSubtree(key: section.anchorKey, child: body));
      } else {
        widgets.add(body);
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Future<void> _startFocusSession() async {
    if (_isLocked) return;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => const _FocusSessionDialog(),
    );
    if (!mounted || minutes == null || minutes <= 0) return;
    setState(() {
      _focusMinutes += minutes;
      _hasChanges = true;
    });
    await _save();
    if (mounted && !_saveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $minutes focus minutes to this note · Total $_focusMinutes min')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLocked && !_privateUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private note')),
        body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.security_rounded, size: 56),
          const SizedBox(height: 16),
          Text('This note is private', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Unlock with your biometric or PIN to view it.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _unlocking ? null : _unlockPrivateNote, icon: const Icon(Icons.lock_open_rounded), label: Text(_unlocking ? 'Unlocking…' : 'Unlock note')),
        ]))),
      );
    }

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: _isZenMode ? const Color(0xFFF2FBF7) : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Keep the writing area unobstructed. Voice capture lives in the
      // formatting toolbar, not in a floating button over the note text.
      floatingActionButton: _isZenMode
          ? FloatingActionButton.small(
              tooltip: 'Exit Zen Mode',
              onPressed: () => setState(() => _isZenMode = false),
              child: const Icon(Icons.center_focus_strong),
            )
          : null,
      appBar: _isZenMode ? null : AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saveFailed ? _save : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_saving)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _saveFailed
                        ? Icons.error_outline_rounded
                        : (_hasChanges ? Icons.edit_outlined : Icons.cloud_done_outlined),
                    size: 17,
                    color: _saveFailed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 7),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : (_saveFailed
                            ? 'Save failed · Retry'
                            : (_hasChanges ? 'Unsaved changes' : 'Saved')),
                    key: ValueKey('$_saving-$_hasChanges-$_saveFailed'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _saveFailed
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Link options',
            icon: Badge(
              isLabelVisible: _linkedNoteIds.isNotEmpty,
              label: Text('${_linkedNoteIds.length}'),
              child: const Icon(Icons.link_rounded),
            ),
            onSelected: (value) {
              switch (value) {
                case 'note':
                  _manageLinkedNotes();
                  break;
                case 'kanban':
                  _linkToKanban();
                  break;
                case 'view':
                  _showKanbanBacklinks();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!_isLocked)
                const PopupMenuItem(
                  value: 'note',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.note_add_outlined),
                    title: Text('Link to note'),
                  ),
                ),
              if (!_isLocked)
                const PopupMenuItem(
                  value: 'kanban',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.view_kanban_outlined),
                    title: Text('Link to Kanban'),
                  ),
                ),
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link_outlined),
                  title: Text('View linked items'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: _isZenMode ? 'Exit Zen Mode' : 'Zen Mode',
            onPressed: () => setState(() => _isZenMode = !_isZenMode),
            icon: const Icon(Icons.center_focus_strong),
          ),
          IconButton(
            tooltip: _previewMode ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _previewMode = !_previewMode),
            icon: Icon(_previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'Add Image',
            onPressed: () => _addImage(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined),
          ),
          if (widget.note != null && !_isLocked && widget.repository is LocalNoteRepository)
            IconButton(
              tooltip: 'Version history',
              onPressed: _showVersionHistory,
              icon: const Icon(Icons.history_rounded),
            ),
          IconButton(
            tooltip: _isPinned ? 'Unpin' : 'Pin',
            onPressed: () => _setFlag(pinned: !_isPinned),
            icon: const OrahAssetIcon('pin'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.document_scanner_outlined),
            onSelected: (value) async {
              switch (value) {
                case 'add_image': await _addImage(ImageSource.gallery); return;
                case 'scan_document': await _scanDocumentToJpg(); return;
                case 'ocr': await _scanTextFromImage(); return;
                case 'template': await _showTemplates(); return;
                case 'reminder': await _setDueDate(); return;
                case 'clear_reminder': await _clearDueDate(); return;
                case 'color':
                  await _showNoteColorPicker();
                  return;
                case 'share_card':
                  await _shareNoteCard();
                  return;
                case 'export':
                  await _save();
                  if (!mounted) return;
                  await showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => ExportNoteSheet(
                      note: Note(
                        id: _noteId,
                        title: _titleController.text.trim().isEmpty ? 'Untitled note' : _titleController.text.trim(),
                        content: _contentController.text,
                        type: _noteType,
                        attachments: _attachments,
                        checklistItems: _checklistItems,
                        createdAt: _createdAt,
                        updatedAt: DateTime.now(),
                        folderId: _folderId,
                        tags: _tags,
                        isPinned: _isPinned,
                        isFavorite: _isFavorite,
                        isArchived: _isArchived,
                        isTrashed: false,
                        dueAt: _dueAt,
                        mood: _mood,
                      ),
                    ),
                  );
                  return;
                case 'favorite':
                  await _setFlag(favorite: !_isFavorite);
                  return;
                case 'organize':
                  await _organize();
                  return;
                case 'archive':
                  await _setFlag(archived: !_isArchived);
                  return;
                case 'lock':
                  await _lockNote();
                  return;
                case 'unlock_note':
                  await _unlockNotePermanently();
                  return;
                case 'delete':
                  await _delete();
                  return;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share_card',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image_outlined),
                  title: Text('Export as Card'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: OrahAssetIcon('share'),
                  title: Text('Export'),
                ),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const OrahAssetIcon('star'),
                  title: Text(
                    _isFavorite ? 'Remove favorite' : 'Add to favorites',
                  ),
                ),
              ),
              const PopupMenuItem(value: 'add_image', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.image_outlined), title: Text('Add image'))),
              if (Platform.isAndroid) const PopupMenuItem(value: 'scan_document', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.document_scanner_outlined), title: Text('Scan document (JPG)'))),
              const PopupMenuItem(value: 'ocr', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.document_scanner_outlined), title: Text('Scan text from image'))),
              const PopupMenuItem(value: 'template', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.auto_awesome_outlined), title: Text('Template'))),
              PopupMenuItem(value: 'reminder', child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notifications_outlined), title: Text(_dueAt == null ? 'Set reminder' : 'Reminder: ' + DateFormat('d MMM, h:mm a').format(_dueAt!)))),
              if (_dueAt != null) const PopupMenuItem(value: 'clear_reminder', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.notifications_off_outlined), title: Text('Clear reminder'))),
              const PopupMenuItem(
                value: 'color',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.palette_outlined), title: Text('Note color')),
              ),
              const PopupMenuItem(
                value: 'organize',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: OrahAssetIcon('tag'),
                  title: Text('Folder & tags'),
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(_isArchived ? 'Unarchive' : 'Archive'),
                ),
              ),
              if (!_isLocked)
                const PopupMenuItem(
                  value: 'lock',
                  child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock_outline_rounded), title: Text('Lock note')),
                ),
              if (_isLocked && _privateUnlocked)
                const PopupMenuItem(
                  value: 'unlock_note',
                  child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock_open_rounded), title: Text('Unlock and move to Notes')),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: OrahAssetIcon('trash'),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: OrahContentFrame(child: SafeArea(
        child: Column(
          children: [
            if (_isListening || _speechInitializing || _voiceProcessing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_isListening ? Colors.red : const Color(0xFFF97316))
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_isListening ? Colors.red : const Color(0xFFF97316))
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_speechInitializing || _voiceProcessing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.fiber_manual_record_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isListening
                                  ? 'Recording • ${_formatVoiceDuration()}'
                                  : (_voiceProcessing ? 'Saving voice text…' : 'Preparing microphone…'),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if (_speechInitializing || _voiceProcessing) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (_isListening) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _cancelVoiceInput,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Cancel'),
                            ),
                            TextButton.icon(
                              onPressed: _retryVoiceInput,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                            ),
                            FilledButton.icon(
                              onPressed: _stopAndSaveVoiceInput,
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Stop & Save'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_folderId != null || _tags.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(
                  children: [
                    if (_folderId != null)
                      _MetaChip(
                        icon: const OrahAssetIcon('folder', size: 16),
                        label: _folderId!,
                      ),
                    ..._tags.map(
                      (tag) => _MetaChip(
                        icon: const OrahAssetIcon('tag', size: 16),
                        label: tag,
                      ),
                    ),
                  ],
                ),
              ),
            if (_imagePath != null && !_attachments.contains(_imagePath) && File(_imagePath!).existsSync())
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_imagePath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (!_isLocked)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton.filledTonal(
                          tooltip: 'Insert image into note body',
                          onPressed: () => _insertImageIntoBody(_imagePath!),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                      ),
                  ],
                ),
              ),
            if (_attachments.isNotEmpty)
              SizedBox(
                height: 112,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = _attachments[index];
                    final isImage = ['.jpg','.jpeg','.png','.webp','.gif','.heic']
                        .contains(p.extension(path).toLowerCase());
                    return Stack(
                      children: [
                        Container(
                          width: 104,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isImage
                              ? GestureDetector(onTap: () => _previewAttachment(path), child: Image.file(File(path), fit: BoxFit.cover))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.insert_drive_file_outlined, size: 26),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        p.basename(path),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton.filledTonal(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showAttachmentActions(path),
                            icon: const OrahAssetIcon('menu', size: 16),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Expanded(
              child: Screenshot(
                controller: _noteCardScreenshotController,
                child: Theme(
                  data: _isCapturingNoteCard ? ThemeData.light() : theme,
                  child: Container(
                    color: _isCapturingNoteCard
                        ? const Color(0xFFFAFAFA)
                        : theme.colorScheme.surface,
                    child: RepaintBoundary(
                  child: _previewMode
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                      children: [
                        if (_titleController.text.trim().isNotEmpty)
                          Text(
                            _titleController.text.trim(),
                            style: (_isCapturingNoteCard
                                    ? ThemeData.light().textTheme
                                    : theme.textTheme)
                                .headlineSmall
                                ?.copyWith(
                                  color: _isCapturingNoteCard
                                      ? const Color(0xFF202124)
                                      : null,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        const SizedBox(height: 12),
                        ..._buildPreviewMarkdownWidgets(theme),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _previewAppendController,
                          minLines: 2,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Continue writing',
                            hintText: 'Type more text without hiding your images…',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            suffixIcon: IconButton(
                              tooltip: 'Add text to note',
                              onPressed: _appendPreviewText,
                              icon: const Icon(Icons.send_rounded),
                            ),
                          ),
                          onSubmitted: (_) => _appendPreviewText(),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                      children: [
                        if (!_previewMode) _MoodSelector(
                          selectedMood: _mood,
                          onSelected: (mood) async {
                            setState(() {
                              _mood = mood;
                              _hasChanges = true;
                            });
                            await _save();
                          },
                        ),
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          style: (_isCapturingNoteCard
                                  ? ThemeData.light().textTheme
                                  : theme.textTheme)
                              .headlineSmall
                              ?.copyWith(
                                color: _isCapturingNoteCard
                                    ? const Color(0xFF202124)
                                    : null,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                          decoration: const InputDecoration(hintText: 'Title', filled: false, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        if (_showSlashCommandMenu && !_previewMode && _noteType != NoteType.checklist)
                          _buildSlashCommandMenu(theme),
                        if (_noteType == NoteType.checklist)
                          _ChecklistEditor(items: _checklistItems, onAdd: _addChecklistItem, onToggle: _toggleChecklistItem, onEdit: _editChecklistItem, onDelete: _removeChecklistItem, onSetReminder: _setChecklistItemReminder, onClearReminder: _clearChecklistItemReminder, onReorder: _reorderChecklist)
                        else
                          TextField(
                            controller: _contentController,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            focusNode: _contentFocus,
                            textInputAction: TextInputAction.newline,
                            minLines: 18,
                            maxLines: null,
                            style: (_isCapturingNoteCard
                                    ? ThemeData.light().textTheme
                                    : theme.textTheme)
                                .bodyLarge
                                ?.copyWith(
                                  color: _isCapturingNoteCard
                                      ? const Color(0xFF202124)
                                      : null,
                                  height: 1.55,
                                ),
                            decoration: const InputDecoration(hintText: 'Start writing...', filled: false, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                          ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              elevation: 4,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // The voice control is part of this toolbar, so controls
                  // use normal edge padding and never sit beneath a floating mic.
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(
                    children: [
                      _ToolButton(
                        icon: Icons.format_bold_rounded,
                        label: 'Bold',
                        onPressed: () => _wrapSelection('**', '**'),
                      ),
                      _ToolButton(
                        icon: Icons.format_italic_rounded,
                        label: 'Italic',
                        onPressed: () => _wrapSelection('*', '*'),
                      ),
                      _ToolButton(
                        icon: Icons.strikethrough_s_rounded,
                        label: 'Strikethrough',
                        onPressed: () => _wrapSelection('~~', '~~'),
                      ),
                      _ToolButton(
                        icon: Icons.title_rounded,
                        label: 'Heading',
                        onPressed: () => _insertPrefix('## '),
                      ),
                      _ToolButton(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'Bullets',
                        onPressed: () => _insertPrefix('- '),
                      ),
                      _ToolButton(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Numbered list',
                        onPressed: () => _insertPrefix('1. '),
                      ),
                      _ToolButton(
                        icon: Icons.format_quote_rounded,
                        label: 'Quote',
                        onPressed: () => _insertPrefix('> '),
                      ),
                      _ToolButton(
                        icon: Icons.insert_link_rounded,
                        label: 'Insert web link',
                        onPressed: _insertLink,
                      ),
                      _ToolButton(
                        assetIcon: _noteType == NoteType.checklist ? 'notes' : 'checklist',
                        label: _noteType == NoteType.checklist
                            ? 'Text note'
                            : 'Checklist',
                        onPressed: () {
                          setState(() {
                            _noteType = _noteType == NoteType.checklist
                                ? NoteType.text
                                : NoteType.checklist;
                            _hasChanges = true;
                          });
                          _save();
                        },
                      ),
                      _ToolButton(
                        assetIcon: 'tag',
                        label: 'Folder & tags',
                        onPressed: _organize,
                      ),
                      _ToolButton(
                        icon: Icons.add_photo_alternate_outlined,
                        label: 'Insert image in body',
                        onPressed: () => _addImageToBody(ImageSource.gallery),
                      ),
                      _ToolButton(
                        icon: Icons.attach_file_rounded,
                        label: 'Add image or file',
                        onPressed: _showAttachmentMenu,
                      ),
                      _ToolButton(
                        icon: Icons.timer_outlined,
                        label: _focusMinutes > 0 ? 'Focus session · $_focusMinutes min' : 'Focus session',
                        onPressed: _startFocusSession,
                      ),
                      _ToolButton(
                        icon: Icons.notifications_active_outlined,
                        label: _dueAt == null ? 'Set reminder' : 'Edit reminder',
                        onPressed: _setDueDate,
                      ),
                      _ToolButton(
                        icon: _isListening ? Icons.stop_circle_outlined : null,
                        assetIcon: _isListening ? null : 'microphone',
                        label: _isListening ? 'Stop voice input' : 'Voice input',
                        onPressed: _toggleVoiceInput,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        )),
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({
    required this.selectedMood,
    required this.onSelected,
  });

  final String? selectedMood;
  final ValueChanged<String?> onSelected;

  static const moods = <(String, String, String)>[
    ('happy', '😊', 'Happy'),
    ('neutral', '😐', 'Neutral'),
    ('sad', '😢', 'Sad'),
    ('angry', '😡', 'Angry'),
    ('thoughtful', '🤔', 'Thoughtful'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling?', style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final mood in moods)
                Tooltip(
                  message: mood.$3,
                  child: ChoiceChip(
                    label: Text(mood.$2, style: const TextStyle(fontSize: 18)),
                    selected: selectedMood == mood.$1,
                    onSelected: (_) => onSelected(selectedMood == mood.$1 ? null : mood.$1),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistEditor extends StatelessWidget {
  const _ChecklistEditor({
    required this.items,
    required this.onAdd,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSetReminder,
    required this.onClearReminder,
    required this.onReorder,
  });

  final List<ChecklistItem> items;
  final VoidCallback onAdd;
  final Future<void> Function(int, bool) onToggle;
  final Future<void> Function(int) onEdit;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(int) onSetReminder;
  final Future<void> Function(int) onClearReminder;
  final Future<void> Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    final done = items.where((item) => item.isDone).length;
    final progress = items.isEmpty ? 0.0 : done / items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isNotEmpty)
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: progress)),
              const SizedBox(width: 12),
              Text('$done/${items.length}'),
            ],
          ),
        if (items.isNotEmpty) const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                OrahAssetIcon('checklist', size: 44, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                const Text('Your checklist is empty'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const OrahAssetIcon('plus'),
                  label: const Text('Add first task'),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < items.length; index++)
                _ChecklistRow(
                  key: ValueKey(items[index].id),
                  item: items[index],
                  canMoveUp: index > 0,
                  canMoveDown: index < items.length - 1,
                  onToggle: (value) => onToggle(index, value),
                  onEdit: () => onEdit(index),
                  onDelete: () => onDelete(index),
                  onSetReminder: () => onSetReminder(index),
                  onClearReminder: () => onClearReminder(index),
                  onMoveUp: index > 0
                      ? () => onReorder(index, index - 1)
                      : null,
                  onMoveDown: index < items.length - 1
                      ? () => onReorder(index, index + 1)
                      : null,
                ),
            ],
          ),
        if (items.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const OrahAssetIcon('plus'),
              label: const Text('Add task'),
            ),
          ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    super.key,
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSetReminder,
    required this.onClearReminder,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ChecklistItem item;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetReminder;
  final VoidCallback onClearReminder;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Checkbox(
          value: item.isDone,
          onChanged: (value) => onToggle(value ?? false),
        ),
        title: Text(
          item.text,
          style: TextStyle(
            decoration: item.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        onTap: () => onToggle(!item.isDone),
        onLongPress: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Move up',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            IconButton(
              tooltip: item.dueAt == null ? 'Set task reminder' : 'Edit task reminder (long-press to clear)',
              onPressed: onSetReminder,
              onLongPress: item.dueAt == null ? null : onClearReminder,
              icon: Icon(item.dueAt == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded),
            ),
            IconButton(
              tooltip: 'Delete task',
              onPressed: onDelete,
              icon: const OrahAssetIcon('trash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: SizedBox(width: 16, height: 16, child: icon),
        label: Text(label),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    this.icon,
    this.assetIcon,
    required this.label,
    required this.onPressed,
  }) : assert(icon != null || assetIcon != null);

  final IconData? icon;
  final String? assetIcon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isVoice = label == 'Voice input' || label == 'Stop voice input';
    final isStoppingVoice = label == 'Stop voice input';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton.filledTonal(
        tooltip: label,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
          tapTargetSize: MaterialTapTargetSize.padded,
          backgroundColor: isVoice
              ? (isStoppingVoice
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.secondaryContainer)
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: isVoice
              ? (isStoppingVoice
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSecondaryContainer)
              : theme.colorScheme.onSurface,
        ),
        onPressed: onPressed,
        icon: assetIcon != null ? OrahAssetIcon(assetIcon!, size: 20) : Icon(icon!, size: 21),
      ),
    );
  }
}

class _ResizableInlineImage extends StatefulWidget {
  const _ResizableInlineImage({
    required this.file,
    required this.width,
    required this.caption,
    required this.onWidthChanged,
    required this.onCaptionChanged,
  });

  final File file;
  final double width;
  final String caption;
  final ValueChanged<double> onWidthChanged;
  final Future<void> Function(String) onCaptionChanged;

  @override
  State<_ResizableInlineImage> createState() => _ResizableInlineImageState();
}

class _ResizableInlineImageState extends State<_ResizableInlineImage> {
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = widget.width;
  }

  @override
  void didUpdateWidget(covariant _ResizableInlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) _width = widget.width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
          final displayWidth = _width.clamp(120.0, maxWidth).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  widget.file,
                  width: displayWidth,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('Image unavailable'),
                ),
              ),
              const SizedBox(height: 4),
              if (widget.caption.trim().isNotEmpty &&
                  widget.caption.trim() != p.basename(widget.file.path))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Make image smaller',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed: () {
                      final next = (_width - 40).clamp(120.0, maxWidth).toDouble();
                      setState(() => _width = next);
                      widget.onWidthChanged(next);
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(displayWidth.round().toString() + ' px', style: theme.textTheme.labelSmall),
                  TextButton.icon(
                    onPressed: () async {
                      final controller = TextEditingController(
                        text: widget.caption == p.basename(widget.file.path)
                            ? ''
                            : widget.caption,
                      );
                      final value = await showDialog<String>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Image caption'),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Add a short caption',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                controller.text.trim(),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      controller.dispose();
                      if (value != null) await widget.onCaptionChanged(value);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(
                      widget.caption.trim().isNotEmpty &&
                              widget.caption.trim() != p.basename(widget.file.path)
                          ? 'Edit caption'
                          : 'Add caption',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Make image larger',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed: () {
                      final next = (_width + 40).clamp(120.0, maxWidth).toDouble();
                      setState(() => _width = next);
                      widget.onWidthChanged(next);
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FocusSessionDialog extends StatefulWidget {
  const _FocusSessionDialog();

  @override
  State<_FocusSessionDialog> createState() => _FocusSessionDialogState();
}

class _FocusSessionDialogState extends State<_FocusSessionDialog> {
  static const int _sessionLengthSeconds = 25 * 60;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = false;

  int get _remainingSeconds => _sessionLengthSeconds - _elapsedSeconds;

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  void _startOrPause() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remainingSeconds <= 0) return;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        Navigator.of(context).pop(25);
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  void _finish() {
    _timer?.cancel();
    final minutes = _elapsedSeconds ~/ 60;
    Navigator.of(context).pop(minutes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Focus session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            _formatDuration(_remainingSeconds),
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          const Text('25-minute Pomodoro · focus on this note'),
          const SizedBox(height: 8),
          Text('Elapsed: ${_formatDuration(_elapsedSeconds)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _finish,
          child: const Text('Finish & save'),
        ),
        FilledButton(
          onPressed: _startOrPause,
          child: Text(_running ? 'Pause' : 'Start'),
        ),
      ],
    );
  }
}

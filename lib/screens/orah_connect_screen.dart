import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class OrahConnectScreen extends StatefulWidget {
  const OrahConnectScreen({
    super.key,
    required this.noteTitle,
    required this.noteContent,
  });

  final String noteTitle;
  final String noteContent;

  @override
  State<OrahConnectScreen> createState() => _OrahConnectScreenState();
}

class _OrahConnectScreenState extends State<OrahConnectScreen> {
  late final TextEditingController _captionController;
  String _platform = 'LinkedIn';
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();
    final title = widget.noteTitle.trim();
    final body = widget.noteContent.trim();
    _captionController = TextEditingController(
      text: [if (title.isNotEmpty) title, if (body.isNotEmpty) body]
          .join('\n\n'),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _explainConnectionSetup(String platform) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Connect ' + platform),
        content: Text(
          platform + ' sign-in is not configured in this build yet. '
          'ORAH needs the platform-approved OAuth flow and publishing permissions '
          'before it can connect an account or publish on your behalf. '
          'Do not enter or share your social-media password with ORAH.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledDate = date;
      _scheduledTime = time;
    });
  }

  Future<void> _schedulePost() async {
    if (_scheduledDate == null || _scheduledTime == null) {
      await _pickSchedule();
      return;
    }
    if (!mounted) return;
    final dateLabel =
        MaterialLocalizations.of(context).formatMediumDate(_scheduledDate!);
    final timeLabel = _scheduledTime!.format(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scheduling setup required'),
        content: Text(
          'Your selected time is ' + dateLabel + ' at ' + timeLabel + '. '
          'This is only a preview: ORAH cannot schedule or publish the post '
          'until account sign-in, platform permissions, and the publishing service '
          'are configured. Nothing has been scheduled or posted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareManually() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a caption before sharing.')),
      );
      return;
    }
    await Share.share(
      caption,
      subject: widget.noteTitle.trim().isEmpty
          ? 'ORAH note'
          : widget.noteTitle.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduledLabel = _scheduledDate == null || _scheduledTime == null
        ? 'No time selected'
        : MaterialLocalizations.of(context).formatMediumDate(_scheduledDate!) +
            ' · ' +
            _scheduledTime!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORAH Connect'),
        actions: [
          IconButton(
            tooltip: 'Share manually',
            onPressed: _shareManually,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(
            'Turn your note into a social post',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a destination, edit the caption, then share manually or prepare a schedule.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'LinkedIn',
                icon: Icon(Icons.work_outline_rounded),
                label: Text('LinkedIn'),
              ),
              ButtonSegment<String>(
                value: 'Instagram',
                icon: Icon(Icons.camera_alt_outlined),
                label: Text('Instagram'),
              ),
            ],
            selected: {_platform},
            onSelectionChanged: (selection) =>
                setState(() => _platform = selection.first),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(
                  _platform == 'LinkedIn'
                      ? Icons.work_outline_rounded
                      : Icons.camera_alt_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              title: Text(_platform + ' account'),
              subtitle: const Text('Not connected'),
              trailing: OutlinedButton(
                onPressed: () => _explainConnectionSetup(_platform),
                child: const Text('Connect'),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Post caption', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            minLines: 7,
            maxLines: 14,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write your post...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schedule for later',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scheduledLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickSchedule,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Choose date & time'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _schedulePost,
                      icon: const Icon(Icons.schedule_send_rounded),
                      label: const Text('Schedule post'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scheduling is a preview until official account login and publishing access are configured. ORAH will not claim a post is scheduled unless the platform confirms it.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _shareManually,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text('Share ' + _platform + ' manually'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manual sharing opens Android’s share sheet. The destination app may require its own login and may not support text-only posting. ORAH does not receive your social-media password.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scheduled_post.dart';
import '../services/orah_reminder_service.dart';
import '../services/orah_scheduled_post_store.dart';

class OrahConnectScreen extends StatefulWidget {
  const OrahConnectScreen({
    super.key,
    required this.noteTitle,
    required this.noteContent,
    this.scheduledPostId,
    this.preferredPlatform,
  });

  final String noteTitle;
  final String noteContent;
  final String? scheduledPostId;
  final String? preferredPlatform;

  @override
  State<OrahConnectScreen> createState() => _OrahConnectScreenState();
}

class _OrahConnectScreenState extends State<OrahConnectScreen> {
  late final TextEditingController _captionController;
  String? _selectedPlatform;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  static const _platforms = <_SharePlatform>[
    _SharePlatform('WhatsApp', Icons.chat_rounded, Color(0xFF25D366)),
    _SharePlatform('Instagram', Icons.camera_alt_rounded, Color(0xFFE1306C)),
    _SharePlatform('Facebook', Icons.facebook, Color(0xFF1877F2)),
    _SharePlatform('LinkedIn', Icons.work_rounded, Color(0xFF0A66C2)),
    _SharePlatform('Telegram', Icons.send_rounded, Color(0xFF229ED9)),
    _SharePlatform('X', Icons.close_rounded, Color(0xFF111111)),
    _SharePlatform('VK', Icons.groups_rounded, Color(0xFF0077FF)),
    _SharePlatform('LINE', Icons.chat_bubble_rounded, Color(0xFF06C755)),
    _SharePlatform('KakaoTalk', Icons.forum_rounded, Color(0xFFFEE500)),
    _SharePlatform('Snapchat', Icons.photo_camera_rounded, Color(0xFFFFD400)),
    _SharePlatform('YouTube', Icons.play_circle_fill_rounded, Color(0xFFFF0033)),
    _SharePlatform('Substack', Icons.article_rounded, Color(0xFFFF6719)),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPlatform = widget.preferredPlatform;
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

  Future<void> _shareToPlatform(_SharePlatform platform) async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a caption before sharing.')),
      );
      return;
    }

    setState(() => _selectedPlatform = platform.name);
    await SharePlus.instance.share(
      ShareParams(
        text: caption,
        subject: widget.noteTitle.trim().isEmpty
            ? 'ORAH note'
            : widget.noteTitle.trim(),
      ),
    );
    final scheduledPostId = widget.scheduledPostId;
    if (scheduledPostId != null) {
      await OrahScheduledPostStore.instance.markCompleted(scheduledPostId);
      await OrahReminderService.instance.cancelConnectPost(scheduledPostId);
    }
  }

  Future<void> _schedulePost() async {
    final date = _scheduledDate;
    final time = _scheduledTime;
    final caption = _captionController.text.trim();
    final platform = _selectedPlatform ?? widget.preferredPlatform;
    if (date == null || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a date and time first.')),
      );
      return;
    }
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a caption before scheduling.')),
      );
      return;
    }
    if (platform == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a destination before scheduling.')),
      );
      return;
    }
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!when.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return;
    }

    final id = 'connect-${DateTime.now().microsecondsSinceEpoch}';
    final post = ScheduledPost(
      id: id,
      platform: platform,
      caption: caption,
      scheduledAt: when,
    );
    try {
      await OrahScheduledPostStore.instance.save(post);
      await OrahReminderService.instance.scheduleConnectPost(
        postId: id,
        platform: platform,
        caption: caption,
        when: when,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved locally. ORAH will remind you to share on $platform.'),
        ),
      );
    } catch (error) {
      await OrahScheduledPostStore.instance.delete(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule reminder: $error')),
      );
    }
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

  Future<void> _explainSchedulingStatus() async {
    final scheduled = _scheduledDate != null && _scheduledTime != null;
    final when = scheduled
        ? '${MaterialLocalizations.of(context).formatMediumDate(_scheduledDate!)} at ${_scheduledTime!.format(context)}'
        : 'no date or time selected';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scheduling is coming next'),
        content: Text(
          'You selected $when. ORAH Connect currently shares through your phone’s share sheet. '
          'This date/time is only a draft preference: no post or reminder has been scheduled, '
          'and nothing will publish automatically yet. We are keeping this version free by '
          'avoiding paid publishing APIs and server hosting.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _platforms.where((item) => item.name == _selectedPlatform);
    final selectedPlatform = selected.isEmpty ? null : selected.first;
    final scheduledLabel = _scheduledDate == null || _scheduledTime == null
        ? 'Choose a date and time (optional)'
        : '${MaterialLocalizations.of(context).formatMediumDate(_scheduledDate!)} · ${_scheduledTime!.format(context)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORAH Connect'),
        actions: [
          IconButton(
            tooltip: 'Open share sheet',
            onPressed: selectedPlatform == null
                ? () => _shareToPlatform(_platforms.first)
                : () => _shareToPlatform(selectedPlatform),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(
            'Your note, ready to share',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick an app below. ORAH opens your device’s share sheet—choose the destination there.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final platform in _platforms)
                _PlatformTile(
                  platform: platform,
                  selected: _selectedPlatform == platform.name,
                  onTap: () => _shareToPlatform(platform),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text('Post text', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(text: _captionController.text.trim()),
                  );
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            minLines: 5,
            maxLines: 12,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write something to share…',
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
                          'Schedule a post',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const Chip(
                        label: Text('Coming soon'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No API fees, no account login. Choose a reminder time for planning; automatic publishing is not enabled yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickSchedule,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(scheduledLabel),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _schedulePost,
                      icon: const Icon(Icons.schedule_send_rounded),
                      label: const Text('Schedule reminder'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Free sharing through your device. App availability and supported content vary by phone and destination. ORAH does not log in to social accounts or publish automatically in this version.',
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

class _SharePlatform {
  const _SharePlatform(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({
    required this.platform,
    required this.selected,
    required this.onTap,
  });

  final _SharePlatform platform;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Material(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: platform.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    platform.icon,
                    color: platform.name == 'KakaoTalk' ||
                            platform.name == 'Snapchat'
                        ? const Color(0xFF202020)
                        : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  platform.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Free share',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

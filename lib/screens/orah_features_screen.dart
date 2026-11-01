import 'package:flutter/material.dart';
import '../core/widgets/nova_polish.dart';

/// Product-facing feature catalogue. Status labels intentionally distinguish
/// implemented functionality from work that is not yet ready to advertise.
class OrahFeaturesScreen extends StatelessWidget {
  const OrahFeaturesScreen({super.key});

  static const _categories = <_FeatureCategory>[
    _FeatureCategory(
      title: 'Capture',
      description: 'Get thoughts, files and ideas into ORAH quickly.',
      icon: Icons.add_circle_outline_rounded,
      features: [
        _Feature('Quick Capture', 'Create a note or checklist from the home screen.', Icons.bolt_rounded),
        _Feature('Voice Capture', 'Speak naturally and turn speech into note text.', Icons.mic_none_rounded),
        _Feature('Document Scanner', 'Scan pages, auto-crop and enhance them, then save as JPG.', Icons.document_scanner_outlined, detail: 'Android'),
        _Feature('OCR', 'Extract readable text from supported images.', Icons.document_scanner_rounded),
        _Feature('Share to ORAH', 'Send supported text and files from other apps into your inbox.', Icons.share_outlined),
      ],
    ),
    _FeatureCategory(
      title: 'Organise',
      description: 'Keep notes structured and connected.',
      icon: Icons.folder_open_rounded,
      features: [
        _Feature('Folders', 'Group related notes into folders.', Icons.folder_outlined),
        _Feature('Tags & Favourites', 'Label notes and keep important items close.', Icons.sell_outlined),
        _Feature('Archive & Trash', 'Archive notes, restore them, or remove them permanently.', Icons.archive_outlined),
        _Feature('Triage Inbox', 'Review incoming shared content and file or tag it.', Icons.inbox_outlined),
        _Feature('Linked Notes & Merge', 'Connect related notes or combine note content.', Icons.link_rounded, status: _FeatureStatus.inDevelopment),
        _Feature('Kanban Boards', 'Organise work with cards, goals, due dates and checklists.', Icons.view_kanban_outlined),
      ],
    ),
    _FeatureCategory(
      title: 'Write',
      description: 'Create notes that work the way you think.',
      icon: Icons.edit_note_rounded,
      features: [
        _Feature('Checklists', 'Break a note into tasks and mark items complete.', Icons.checklist_rounded),
        _Feature('Slash Commands', 'Type / in the editor to open the block-type menu.', Icons.keyboard_command_key_rounded, status: _FeatureStatus.inDevelopment),
        _Feature('Images & Attachments', 'Attach files or insert an image at the cursor in the note body.', Icons.image_outlined),
        _Feature('Templates', 'Start from a reusable note template.', Icons.dashboard_customize_outlined),
        _Feature('Version History', 'Preview saved snapshots and restore an earlier version.', Icons.history_rounded, status: _FeatureStatus.inDevelopment),
      ],
    ),
    _FeatureCategory(
      title: 'Search',
      description: 'Find the right note without digging through folders.',
      icon: Icons.search_rounded,
      features: [
        _Feature('Universal Search', 'Search notes and expand indexing to linked notes and attachments.', Icons.manage_search_rounded, status: _FeatureStatus.inDevelopment),
        _Feature('One-tap Search Filters', 'Filter by voice, image, checklist or notes from this week.', Icons.filter_alt_outlined),
        _Feature('Sort & Filter', 'Narrow notes by type, folder, favourites and other filters.', Icons.tune_rounded),
      ],
    ),
    _FeatureCategory(
      title: 'Productivity',
      description: 'Turn notes into a practical daily workflow.',
      icon: Icons.event_available_rounded,
      features: [
        _Feature('Reminders & Calendar', 'Schedule reminders and browse notes by date.', Icons.calendar_month_outlined),
        _Feature('Deadline Countdown', 'See countdown cues for notes with deadlines.', Icons.hourglass_bottom_rounded),
        _Feature('Kanban Goals & Timers', 'Track goals, linked cards and time spent.', Icons.timer_outlined),
        _Feature('Daily Reflection', 'Use a daily prompt and optional scheduled reminder.', Icons.auto_awesome_outlined),
        _Feature('Writing Insights', 'Review note totals, streaks, weekly activity and mood trends.', Icons.insights_outlined),
      ],
    ),
    _FeatureCategory(
      title: 'Security',
      description: 'Keep private notes protected and your data under your control.',
      icon: Icons.shield_outlined,
      features: [
        _Feature('Private Vault', 'Protect private notes with Vault authentication.', Icons.lock_outline_rounded),
        _Feature('PIN & Biometrics', 'Use app PIN protection and supported biometric unlock.', Icons.fingerprint_rounded),
        _Feature('Vault Auto-lock', 'Choose when the Vault should require authentication again.', Icons.timer_outlined),
        _Feature('Local-first & Offline', 'Keep core notes on your device and work without a connection.', Icons.phonelink_lock_outlined),
      ],
    ),
    _FeatureCategory(
      title: 'Data',
      description: 'Take your notes with you and stay in control of your archive.',
      icon: Icons.storage_rounded,
      features: [
        _Feature('Portable Backup & Restore', 'Package notes, folders and attachments into a .nova backup.', Icons.backup_outlined),
        _Feature('Export & Share', 'Export supported notes as PDF, Word, plain text, Markdown or Excel where enabled.', Icons.ios_share_rounded),
        _Feature('Email Attachment', 'Create a PDF and share it through your device’s email or sharing app.', Icons.email_outlined),
        _Feature('Additional Export Formats', 'More document, ebook, academic, data and archive formats are planned.', Icons.more_horiz_rounded, status: _FeatureStatus.planned),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Orah Features')),
      body: OrahContentFrame(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryContainer, colors.surfaceContainerHighest],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 30, color: colors.onPrimaryContainer),
                const SizedBox(height: 12),
                Text('Everything you can do with ORAH',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: colors.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text('Explore features by what you want to do. Labels show what is available, still being verified, or planned.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onPrimaryContainer)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: const [
                  _StatusChip(status: _FeatureStatus.available),
                  _StatusChip(status: _FeatureStatus.inDevelopment),
                  _StatusChip(status: _FeatureStatus.planned),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final category in _categories) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: colors.secondaryContainer, borderRadius: BorderRadius.circular(13)),
                    child: Icon(category.icon, color: colors.onSecondaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(category.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(category.description, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    ]),
                  ),
                ],
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < category.features.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 68),
                    _FeatureTile(feature: category.features[i]),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Feature status reflects the current app code. Features marked “In development” are not advertised as fully ready; device verification may still be required.',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      )),
    );
  }
}

enum _FeatureStatus { available, inDevelopment, planned }

class _FeatureCategory {
  const _FeatureCategory({required this.title, required this.description, required this.icon, required this.features});
  final String title;
  final String description;
  final IconData icon;
  final List<_Feature> features;
}

class _Feature {
  const _Feature(this.title, this.description, this.icon, {this.status = _FeatureStatus.available, this.detail});
  final String title;
  final String description;
  final IconData icon;
  final _FeatureStatus status;
  final String? detail;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurface,
        child: Icon(feature.icon),
      ),
      title: Text(feature.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(feature.description),
            if (feature.detail != null) ...[
              const SizedBox(height: 4),
              Text(feature.detail!, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: _StatusChip(status: feature.status)),
          ],
        ),
      ),
      isThreeLine: true,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _FeatureStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (status) {
      _FeatureStatus.available => ('Available', Icons.check_circle_outline_rounded, colors.tertiaryContainer, colors.onTertiaryContainer),
      _FeatureStatus.inDevelopment => ('In development', Icons.pending_outlined, colors.secondaryContainer, colors.onSecondaryContainer),
      _FeatureStatus.planned => ('Coming soon', Icons.schedule_rounded, colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: foreground),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

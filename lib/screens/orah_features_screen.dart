import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/widgets/nova_polish.dart';

/// Product-facing feature catalogue. Status labels intentionally distinguish
/// implemented functionality from work that is not yet ready to advertise.
class OrahFeaturesScreen extends StatefulWidget {
  const OrahFeaturesScreen({super.key});

  @override
  State<OrahFeaturesScreen> createState() => _OrahFeaturesScreenState();
}

class _OrahFeaturesScreenState extends State<OrahFeaturesScreen> {
  static const _shortcutsKey = 'orah_feature_shortcuts_v1';
  List<String> _shortcutTitles = const ['Quick Capture', 'Voice Capture', 'Universal Search', 'Linked Notes & Merge'];
  bool _preferencesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _shortcutTitles = prefs.getStringList(_shortcutsKey) ?? _shortcutTitles;
      _preferencesLoaded = true;
    });
  }

  Future<void> _saveShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_shortcutsKey, _shortcutTitles);
  }

  List<_Feature> get _allFeatures => _categories.expand((category) => category.features).toList();

  Future<void> _addFeature() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final available = _allFeatures.where((feature) => !_shortcutTitles.contains(feature.title)).toList();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(children: [
                    const Expanded(child: Text('Add a feature shortcut', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                  ]),
                ),
                Expanded(
                  child: available.isEmpty
                      ? const Center(child: Text('All available features are already added.'))
                      : ListView.separated(
                          itemCount: available.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final feature = available[index];
                            return ListTile(
                              leading: CircleAvatar(child: Icon(feature.icon)),
                              title: Text(feature.title),
                              subtitle: Text(feature.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.add_circle_outline_rounded),
                              onTap: () => Navigator.pop(sheetContext, feature.title),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || _shortcutTitles.contains(selected)) return;
    setState(() => _shortcutTitles = [..._shortcutTitles, selected]);
    await _saveShortcuts();
  }

  Future<void> _removeFeature(String title) async {
    setState(() => _shortcutTitles = _shortcutTitles.where((item) => item != title).toList());
    await _saveShortcuts();
  }

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
        _Feature('Linked Notes & Merge', 'Connect related notes or combine note content.', Icons.link_rounded),
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

  Widget _shortcutTile(String title, int index, {required Key key}) {
    final matches = _allFeatures.where((item) => item.title == title).toList();
    if (matches.isEmpty) return SizedBox.shrink(key: key);
    final feature = matches.first;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      key: key,
      leading: CircleAvatar(backgroundColor: colors.surfaceContainerHighest, child: Icon(feature.icon)),
      title: Text(feature.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(feature.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Remove shortcut', onPressed: () => _removeFeature(title), icon: const Icon(Icons.remove_circle_outline_rounded)),
        ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded))),
      ]),
    );
  }

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
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('My feature shortcuts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                    FilledButton.tonalIcon(onPressed: _addFeature, icon: const Icon(Icons.add_rounded), label: const Text('Add')),
                  ]),
                  const SizedBox(height: 4),
                  Text('Personalise this page. Drag to reorder, or tap − to remove a shortcut. This only changes your shortcuts, not the app’s actual capabilities.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (!_preferencesLoaded)
                    const LinearProgressIndicator()
                  else if (_shortcutTitles.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('No shortcuts yet. Tap Add to choose features.', style: theme.textTheme.bodyMedium)))
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _shortcutTitles.removeAt(oldIndex);
                          _shortcutTitles.insert(newIndex, item);
                        });
                        await _saveShortcuts();
                      },
                      children: [
                        for (var index = 0; index < _shortcutTitles.length; index++)
                          _shortcutTile(_shortcutTitles[index], index, key: ValueKey(_shortcutTitles[index])),
                      ],
                    ),
                ],
              ),
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

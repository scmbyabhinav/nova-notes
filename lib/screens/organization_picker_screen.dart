import 'package:flutter/material.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../l10n/app_localizations.dart';

import '../models/folder.dart';

class OrganizationPickerScreen extends StatefulWidget {
  const OrganizationPickerScreen({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.selectedTags,
  });

  final List<NoteFolder> folders;
  final String? selectedFolderId;
  final List<String> selectedTags;

  @override
  State<OrganizationPickerScreen> createState() =>
      _OrganizationPickerScreenState();
}

class _OrganizationPickerScreenState extends State<OrganizationPickerScreen> {
  late String? _folderId;
  late final Set<String> _tags;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderId = widget.selectedFolderId;
    _tags = {...widget.selectedTags};
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final value = _tagController.text.trim().replaceAll('#', '');
    if (value.isEmpty) return;

    setState(() {
      _tags.add(value);
      _tagController.clear();
    });
  }

  void _done() {
    Navigator.of(context).pop(
      OrganizationSelection(
        folderId: _folderId,
        tags: _tags.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.organizationPickerTitle),
        actions: [
          TextButton(
            onPressed: _done,
            child: Text(l10n.organizationDone),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Text(
            'Folder',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  groupValue: _folderId,
                  title: Text(l10n.organizationNoFolder),
                  onChanged: (value) => setState(() => _folderId = value),
                ),
                ...widget.folders.map(
                  (folder) => RadioListTile<String>(
                    value: folder.id,
                    groupValue: _folderId,
                    title: Text(folder.name),
                    secondary: const OrahAssetIcon('folder'),
                    onChanged: (value) => setState(() => _folderId = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tags',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(),
                  decoration: const InputDecoration(
                    hintText: l10n.organizationAddTagHint,
                    prefixText: '# ',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addTag,
                child: Text(l10n.organizationAddTag),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tags.isEmpty)
            Text(l10n.organizationNoTags)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map(
                    (tag) => InputChip(
                      label: Text('#$tag'),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class OrganizationSelection {
  const OrganizationSelection({
    required this.folderId,
    required this.tags,
  });

  final String? folderId;
  final List<String> tags;
}

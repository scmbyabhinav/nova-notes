import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../services/universal_export_service.dart';
import '../services/orah_feature_gate.dart';
import '../services/orah_premium_gate.dart';

class ExportNoteSheet extends StatefulWidget {
  const ExportNoteSheet({super.key, required this.note});
  final Note note;

  @override
  State<ExportNoteSheet> createState() => _ExportNoteSheetState();
}

class _ExportNoteSheetState extends State<ExportNoteSheet> {
  bool _busy = false;
  NovaExportFormat _selected = NovaExportFormat.pdf;

  static const _options = <_ExportOption>[
    _ExportOption(NovaExportFormat.pdf, Icons.picture_as_pdf_outlined, 'PDF', 'Printable document', 'Documents', true),
    _ExportOption(NovaExportFormat.word, Icons.description_outlined, 'Word (.docx)', 'Editable Microsoft Word document', 'Documents', false),
    _ExportOption(NovaExportFormat.text, Icons.text_snippet_outlined, 'Text (.txt)', 'Simple universal text', 'Documents', false),
    _ExportOption(NovaExportFormat.markdown, Icons.code_outlined, 'Markdown (.md)', 'Portable Markdown', 'Documents', false),
    _ExportOption(NovaExportFormat.excel, Icons.table_chart_outlined, 'Excel (.xlsx)', 'Spreadsheet; checklists become rows', 'Data', true),
  ];

  Future<void> _exportSelected() async {
    final option = _options.firstWhere((item) => item.format == _selected);
    if (option.premium && !await OrahPremiumGate.check(context, OrahFeature.advancedExport)) return;
    setState(() => _busy = true);
    try {
      final file = await const UniversalExportService().export(widget.note, _selected);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: 'ORAH — ${widget.note.title}', text: 'Exported from ORAH');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendAsEmailAttachment() async {
    setState(() => _busy = true);
    try {
      final file = await const UniversalExportService().export(widget.note, NovaExportFormat.pdf);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: 'ORAH — ${widget.note.title}', text: 'Attached from ORAH');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email attachment failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _options.firstWhere((item) => item.format == _selected);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export note', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Choose one format, then tap Export. Orah never exports every format unless you explicitly choose Export All.'),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            _selectedFormatCard(selected),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _chooseFormat, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Choose format'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _exportSelected, icon: const Icon(Icons.ios_share_rounded), label: Text('Export ${selected.label}'))),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: const Text('Send as email attachment'),
              subtitle: const Text('Creates a PDF and opens the system share sheet'),
              enabled: !_busy,
              onTap: _sendAsEmailAttachment,
            ),
            const SizedBox(height: 4),
            Center(child: TextButton.icon(onPressed: _busy ? null : _exportAllSupported, icon: const Icon(Icons.all_inclusive_rounded, size: 19), label: const Text('Export All Supported Formats'))),
          ],
        ),
      ),
    );
  }

  Widget _selectedFormatCard(_ExportOption option) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(option.icon),
        title: Row(children: [Expanded(child: Text(option.label)), if (option.premium) const Icon(Icons.workspace_premium_rounded, size: 18)]),
        subtitle: Text(option.description),
      ),
    );
  }

  Future<void> _chooseFormat() async {
    final selected = await showModalBottomSheet<NovaExportFormat>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text('Choose one export format', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            for (final category in const ['Documents', 'Data']) _category(context, category),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selected = selected);
  }

  Widget _category(BuildContext context, String category) {
    final items = _options.where((item) => item.category == category).toList();
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(category),
      children: [
        for (final option in items)
          RadioListTile<NovaExportFormat>(
            value: option.format,
            groupValue: _selected,
            secondary: Icon(option.icon),
            title: Row(children: [Expanded(child: Text(option.label)), if (option.premium) const Icon(Icons.workspace_premium_rounded, size: 18)]),
            subtitle: Text(option.description),
            onChanged: (value) { if (value != null) Navigator.of(context).pop(value); },
          ),
      ],
    );
  }

  Future<void> _exportAllSupported() async {
    setState(() => _busy = true);
    final files = <XFile>[];
    try {
      for (final option in _options) {
        if (option.premium && !await OrahPremiumGate.check(context, OrahFeature.advancedExport)) return;
        final file = await const UniversalExportService().export(widget.note, option.format);
        files.add(XFile(file.path));
      }
      if (!mounted) return;
      await Share.shareXFiles(files, subject: 'ORAH — ${widget.note.title} — Export bundle', text: 'Exported from ORAH in all currently supported formats');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export All failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ExportOption {
  const _ExportOption(this.format, this.icon, this.label, this.description, this.category, this.premium);
  final NovaExportFormat format;
  final IconData icon;
  final String label;
  final String description;
  final String category;
  final bool premium;
}

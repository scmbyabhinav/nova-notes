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
    _ExportOption(NovaExportFormat.pdf, Icons.picture_as_pdf_outlined, 'PDF (.pdf)', 'Printable document', 'Documents', true),
    _ExportOption(NovaExportFormat.word, Icons.description_outlined, 'Word (.docx)', 'Editable Microsoft Word document', 'Documents', false),
    _ExportOption(NovaExportFormat.text, Icons.text_snippet_outlined, 'Plain Text (.txt)', 'Maximum compatibility', 'Documents', false),
    _ExportOption(NovaExportFormat.markdown, Icons.code_outlined, 'Markdown (.md)', 'Portable Markdown', 'Documents', false),
    _ExportOption(NovaExportFormat.excel, Icons.table_chart_outlined, 'Excel (.xlsx)', 'Spreadsheet; checklists become rows', 'Data', true),
  ];

  static const _planned = <_PlannedExport>[
    _PlannedExport('Rich Text (.rtf)', 'Cross-platform rich text', 'Documents'),
    _PlannedExport('OpenDocument (.odt)', 'LibreOffice / open standard', 'Documents'),
    _PlannedExport('HTML (.html)', 'Web pages, email and blogs', 'Documents'),
    _PlannedExport('EPUB (.epub)', 'Most ebook readers', 'Ebooks'),
    _PlannedExport('MOBI (.mobi)', 'Older Kindle', 'Ebooks'),
    _PlannedExport('AZW3 (.azw3)', 'Modern Kindle', 'Ebooks'),
    _PlannedExport('FB2 (.fb2)', 'Popular ebook format', 'Ebooks'),
    _PlannedExport('LaTeX (.tex)', 'Research papers and math-heavy documents', 'Academic'),
    _PlannedExport('PDF from LaTeX (.pdf)', 'Final academic papers', 'Academic'),
    _PlannedExport('BibTeX (.bib)', 'Reference management', 'Academic'),
    _PlannedExport('CSV (.csv)', 'Tables and data analysis', 'Data'),
    _PlannedExport('JSON (.json)', 'Developers, APIs and structured data', 'Data'),
    _PlannedExport('XML (.xml)', 'Structured documents', 'Data'),
    _PlannedExport('YAML (.yaml)', 'Configuration and readable data', 'Data'),
    _PlannedExport('TSV (.tsv)', 'Tab-separated tables', 'Data'),
    _PlannedExport('PowerPoint (.pptx)', 'Presentations', 'Presentation'),
    _PlannedExport('MP3 (.mp3)', 'Text-to-speech audio', 'Speech / Audio'),
    _PlannedExport('WAV (.wav)', 'Text-to-speech audio', 'Speech / Audio'),
    _PlannedExport('SRT (.srt)', 'Video subtitles', 'Subtitles'),
    _PlannedExport('VTT (.vtt)', 'Web/video subtitles', 'Subtitles'),
    _PlannedExport('Email (.eml)', 'Email message format', 'Email'),
    _PlannedExport('HTML Email', 'Ready-to-send HTML email', 'Email'),
    _PlannedExport('Jupyter Notebook (.ipynb)', 'Code / literate documents', 'Code / Literate'),
    _PlannedExport('ZIP (.zip)', 'Compressed export bundle', 'Archive'),
    _PlannedExport('7Z (.7z)', 'Compressed export bundle', 'Archive'),
    _PlannedExport('SQLite', 'Database export', 'Database'),
    _PlannedExport('Rich Text Clipboard', 'Rich text clipboard format', 'Clipboard'),
    _PlannedExport('HTML Clipboard', 'HTML clipboard format', 'Clipboard'),
    _PlannedExport('Plain Text Clipboard', 'Plain text clipboard format', 'Clipboard'),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export note',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('Choose exactly one format. The available formats are shown below.'),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Text('Documents', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  for (final option in _options.where((o) => o.category == 'Documents'))
                    _formatTile(option),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 10, bottom: 4),
                    child: Text('Data', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  for (final option in _options.where((o) => o.category == 'Data'))
                    _formatTile(option),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 14, bottom: 4),
                    child: Text('Planned / Coming Soon', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('These formats are planned for future Orah updates.', style: TextStyle(fontSize: 12)),
                  ),
                  for (final category in _plannedCategories)
                    _plannedSection(category),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Send as email attachment'),
                    subtitle: const Text('Creates a PDF and opens the system share sheet'),
                    enabled: !_busy,
                    onTap: _sendAsEmailAttachment,
                  ),
                  const Divider(),
                  Center(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _exportAllSupported,
                      icon: const Icon(Icons.all_inclusive_rounded, size: 19),
                      label: const Text('Export All Available Formats'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatTile(_ExportOption option) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(option.icon),
      title: Row(
        children: [
          Expanded(child: Text(option.label)),
          if (option.premium)
            const Icon(Icons.workspace_premium_rounded, size: 18),
        ],
      ),
      subtitle: Text(option.description),
      enabled: !_busy,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        if (option.premium &&
            !await OrahPremiumGate.check(context, OrahFeature.advancedExport)) {
          return;
        }
        setState(() => _selected = option.format);
        await _exportSelected();
      },
    );
  }

  Future<void> _exportAllSupported() async {
    setState(() => _busy = true);
    final files = <XFile>[];
    try {
      for (final option in _options) {
        if (option.premium &&
            !await OrahPremiumGate.check(context, OrahFeature.advancedExport)) {
          continue;
        }
        final file = await const UniversalExportService().export(widget.note, option.format);
        files.add(XFile(file.path));
      }
      if (!mounted) return;
      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          subject: 'ORAH — ' + widget.note.title + ' — Export bundle',
          text: 'Exported from ORAH in all currently available formats',
        );
      }
      if (mounted) await _showPlannedFormats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export All failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _plannedSection(String category) {
    final items = _planned.where((item) => item.category == category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 2),
          child: Text(category, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline_rounded, size: 20),
            title: Row(
              children: [
                Expanded(child: Text(item.label)),
                const Text(
                  'Coming Soon',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            subtitle: Text(item.description),
            enabled: false,
          ),
      ],
    );
  }

  Future<void> _showPlannedFormats() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Planned Export Formats',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('These formats are planned for future Orah updates and are not exported yet.'),
            const SizedBox(height: 12),
            for (final category in _plannedCategories)
              _plannedSection(category),
          ],
        ),
      ),
    );
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

class _PlannedExport {
  const _PlannedExport(this.label, this.description, this.category);
  final String label;
  final String description;
  final String category;
}

const _plannedCategories = <String>[
  'Documents', 'Ebooks', 'Academic', 'Data', 'Presentation',
  'Speech / Audio', 'Subtitles', 'Email', 'Code / Literate',
  'Archive', 'Database', 'Clipboard',
];

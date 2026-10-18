import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';
import '../services/universal_export_service.dart';
import '../services/orah_feature_gate.dart';
import '../services/orah_premium_gate.dart';
import '../l10n/app_localizations.dart';

class ExportNoteSheet extends StatefulWidget {
  const ExportNoteSheet({super.key, required this.note});
  final Note note;

  @override
  State<ExportNoteSheet> createState() => _ExportNoteSheetState();
}

class _ExportNoteSheetState extends State<ExportNoteSheet> {
  bool _busy = false;
  NovaExportFormat _selected = NovaExportFormat.pdf;

  List<_ExportOption> _options(AppLocalizations l10n) => <_ExportOption>[
    _ExportOption(NovaExportFormat.pdf, Icons.picture_as_pdf_outlined, l10n.exportFormatPdf, l10n.exportDescriptionPdf, l10n.exportDocuments, true),
    _ExportOption(NovaExportFormat.word, Icons.description_outlined, l10n.exportFormatWord, l10n.exportDescriptionWord, l10n.exportDocuments, false),
    _ExportOption(NovaExportFormat.text, Icons.text_snippet_outlined, l10n.exportFormatText, l10n.exportDescriptionText, l10n.exportDocuments, false),
    _ExportOption(NovaExportFormat.markdown, Icons.code_outlined, l10n.exportFormatMarkdown, l10n.exportDescriptionMarkdown, l10n.exportDocuments, false),
    _ExportOption(NovaExportFormat.excel, Icons.table_chart_outlined, l10n.exportFormatExcel, l10n.exportDescriptionExcel, l10n.exportData, true),
  ];

  List<_PlannedExport> _planned(AppLocalizations l10n) => <_PlannedExport>[
    _PlannedExport(l10n.plannedExportRichText, l10n.plannedExportRichTextDescription, l10n.exportDocuments),
    _PlannedExport(l10n.plannedExportOpenDocument, l10n.plannedExportOpenDocumentDescription, l10n.exportDocuments),
    _PlannedExport(l10n.plannedExportHtml, l10n.plannedExportHtmlDescription, l10n.exportDocuments),
    _PlannedExport(l10n.plannedExportEpub, l10n.plannedExportEpubDescription, l10n.exportCategoryEbooks),
    _PlannedExport(l10n.plannedExportMobi, l10n.plannedExportMobiDescription, l10n.exportCategoryEbooks),
    _PlannedExport(l10n.plannedExportAzw3, l10n.plannedExportAzw3Description, l10n.exportCategoryEbooks),
    _PlannedExport(l10n.plannedExportFb2, l10n.plannedExportFb2Description, l10n.exportCategoryEbooks),
    _PlannedExport(l10n.plannedExportLatex, l10n.plannedExportLatexDescription, l10n.exportCategoryAcademic),
    _PlannedExport(l10n.plannedExportLatexPdf, l10n.plannedExportLatexPdfDescription, l10n.exportCategoryAcademic),
    _PlannedExport(l10n.plannedExportBibtex, l10n.plannedExportBibtexDescription, l10n.exportCategoryAcademic),
    _PlannedExport(l10n.plannedExportCsv, l10n.plannedExportCsvDescription, l10n.exportData),
    _PlannedExport(l10n.plannedExportJson, l10n.plannedExportJsonDescription, l10n.exportData),
    _PlannedExport(l10n.plannedExportXml, l10n.plannedExportXmlDescription, l10n.exportData),
    _PlannedExport(l10n.plannedExportYaml, l10n.plannedExportYamlDescription, l10n.exportData),
    _PlannedExport(l10n.plannedExportTsv, l10n.plannedExportTsvDescription, l10n.exportData),
    _PlannedExport(l10n.plannedExportPowerPoint, l10n.plannedExportPowerPointDescription, l10n.exportCategoryPresentation),
    _PlannedExport(l10n.plannedExportMp3, l10n.plannedExportMp3Description, l10n.exportCategorySpeechAudio),
    _PlannedExport(l10n.plannedExportWav, l10n.plannedExportWavDescription, l10n.exportCategorySpeechAudio),
    _PlannedExport(l10n.plannedExportSrt, l10n.plannedExportSrtDescription, l10n.exportCategorySubtitles),
    _PlannedExport(l10n.plannedExportVtt, l10n.plannedExportVttDescription, l10n.exportCategorySubtitles),
    _PlannedExport(l10n.plannedExportEml, l10n.plannedExportEmlDescription, l10n.exportCategoryEmail),
    _PlannedExport(l10n.plannedExportHtmlEmail, l10n.plannedExportHtmlEmailDescription, l10n.exportCategoryEmail),
    _PlannedExport(l10n.plannedExportJupyter, l10n.plannedExportJupyterDescription, l10n.exportCategoryCodeLiterate),
    _PlannedExport(l10n.plannedExportZip, l10n.plannedExportZipDescription, l10n.exportCategoryArchive),
    _PlannedExport(l10n.plannedExport7z, l10n.plannedExport7zDescription, l10n.exportCategoryArchive),
    _PlannedExport(l10n.plannedExportSqlite, l10n.plannedExportSqliteDescription, l10n.exportCategoryDatabase),
    _PlannedExport(l10n.plannedExportRichClipboard, l10n.plannedExportRichClipboardDescription, l10n.exportCategoryClipboard),
    _PlannedExport(l10n.plannedExportHtmlClipboard, l10n.plannedExportHtmlClipboardDescription, l10n.exportCategoryClipboard),
    _PlannedExport(l10n.plannedExportPlainClipboard, l10n.plannedExportPlainClipboardDescription, l10n.exportCategoryClipboard),
  ];

  Future<void> _exportSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final options = _options(l10n);
    final option = options.firstWhere((item) => item.format == _selected);
    if (option.premium && !await OrahPremiumGate.check(context, OrahFeature.advancedExport)) return;
    setState(() => _busy = true);
    try {
      final file = await const UniversalExportService().export(widget.note, _selected);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: l10n.exportShareSubject(widget.note.title), text: l10n.exportShareBody);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportFailed(l10n.genericTryAgain))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _noteShareText(AppLocalizations l10n) {
    final title = widget.note.title.trim();
    final content = widget.note.content.trim();
    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (content.isNotEmpty) parts.add(content);
    if (parts.isEmpty) parts.add(l10n.untitledNote);
    return parts.join('\n\n');
  }

  Future<void> _shareNoteText() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.share(
        _noteShareText(l10n),
        subject: l10n.exportShareSubject(widget.note.title),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(l10n.genericTryAgain))),
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.https('wa.me', '/', <String, String>{
      'text': _noteShareText(l10n),
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.whatsAppUnavailable)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.whatsAppUnavailable)),
        );
      }
    }
  }

  Future<void> _exportToGoogleDrive() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      // The Android share sheet lets the user choose Google Drive (if installed)
      // and select the destination folder. ORAH does not access Drive directly.
      final file = await const UniversalExportService().export(
        widget.note,
        NovaExportFormat.pdf,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        subject: l10n.exportShareSubject(widget.note.title),
        text: l10n.googleDriveExportBody,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(l10n.genericTryAgain))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendAsEmailAttachment() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final file = await const UniversalExportService().export(widget.note, NovaExportFormat.pdf);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: l10n.emailAttachmentSubject(widget.note.title), text: l10n.emailAttachmentBody);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportEmailAttachmentFailed(l10n.genericTryAgain))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exportSheetTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(l10n.exportSheetDescription),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Text(l10n.exportDocuments, style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  for (final option in _options(l10n).where((o) => o.category == 'Documents'))
                    _formatTile(option),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 10, bottom: 4),
                    child: Text(l10n.exportData, style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  for (final option in _options(l10n).where((o) => o.category == 'Data'))
                    _formatTile(option),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 14, bottom: 4),
                    child: Text(l10n.exportPlannedSection, style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(l10n.exportPlannedDescription, style: TextStyle(fontSize: 12)),
                  ),
                  for (final category in _plannedCategories(l10n))
                    _plannedSection(category, l10n),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined),
                    title: Text(l10n.sendAsEmailAttachment),
                    subtitle: Text(l10n.emailAttachmentDescription),
                    enabled: !_busy,
                    onTap: _sendAsEmailAttachment,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.text_snippet_outlined),
                    title: Text(l10n.shareNoteText),
                    subtitle: Text(l10n.shareNoteTextDescription),
                    enabled: !_busy,
                    onTap: _shareNoteText,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_outlined),
                    title: Text(l10n.shareViaWhatsApp),
                    subtitle: Text(l10n.whatsAppShareDescription),
                    enabled: !_busy,
                    onTap: _shareViaWhatsApp,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_to_drive_outlined),
                    title: Text(l10n.googleDriveExport),
                    subtitle: Text(l10n.googleDriveExportDescription),
                    enabled: !_busy,
                    onTap: _exportToGoogleDrive,
                  ),
                  const Divider(),
                  Center(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _exportAllSupported,
                      icon: const Icon(Icons.all_inclusive_rounded, size: 19),
                      label: Text(l10n.exportAllAvailable),
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
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final files = <XFile>[];
    try {
      for (final option in _options(AppLocalizations.of(context)!)) {
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
          subject: l10n.exportAllShareSubject(widget.note.title),
          text: l10n.exportAllShareBody,
        );
      }
      if (mounted) await _showPlannedFormats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportAllFailed(l10n.genericTryAgain))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _plannedSection(String category, AppLocalizations l10n) {
    final items = _planned(l10n).where((item) => item.category == category);
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
                Text(
                  l10n.exportComingSoon,
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
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              l10n.plannedExportFormats,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(l10n.plannedExportFormatsDescription),
            const SizedBox(height: 12),
            for (final category in _plannedCategories(l10n))
              _plannedSection(category, l10n),
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

List<String> _plannedCategories(AppLocalizations l10n) => <String>[
  l10n.exportDocuments,
  l10n.exportCategoryEbooks,
  l10n.exportCategoryAcademic,
  l10n.exportData,
  l10n.exportCategoryPresentation,
  l10n.exportCategorySpeechAudio,
  l10n.exportCategorySubtitles,
  l10n.exportCategoryEmail,
  l10n.exportCategoryCodeLiterate,
  l10n.exportCategoryArchive,
  l10n.exportCategoryDatabase,
  l10n.exportCategoryClipboard,
];

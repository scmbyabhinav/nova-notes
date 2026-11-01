import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';

/// Imports up to four text-based documents and combines them into one ORAH note.
class ImportDocumentsScreen extends StatefulWidget {
  const ImportDocumentsScreen({super.key});

  @override
  State<ImportDocumentsScreen> createState() => _ImportDocumentsScreenState();
}

class _ImportDocumentsScreenState extends State<ImportDocumentsScreen> {
  static const _extensions = <String>['pdf', 'docx', 'txt', 'md', 'markdown'];
  bool _importing = false;
  String? _status;

  Future<void> _pickAndImport() async {
    if (_importing) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensions,
        allowMultiple: true,
        withData: true,
      );
      if (selection == null || selection.files.isEmpty || !mounted) return;
      if (selection.files.length > 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose up to 4 documents at a time.')),
        );
        return;
      }

      setState(() {
        _importing = true;
        _status = 'Reading ${selection.files.length} document(s)…';
      });

      final sections = <String>[];
      final names = <String>[];
      for (final file in selection.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw FormatException('Could not read ${file.name}. Please select it again.');
        }
        final text = await _extractText(file.name, bytes);
        if (text.trim().isEmpty) {
          throw FormatException(
            '${file.name} contains no extractable text. Scanned/image-only PDFs are not supported by text import yet.',
          );
        }
        names.add(file.name);
        sections.add(
          selection.files.length == 1
              ? text.trim()
              : '## ${p.basenameWithoutExtension(file.name)}\n\n${text.trim()}',
        );
      }

      final now = DateTime.now();
      final title = names.length == 1
          ? p.basenameWithoutExtension(names.first).trim()
          : 'Imported documents (${names.length})';
      final note = Note(
        id: 'import_${now.microsecondsSinceEpoch}',
        title: title.isEmpty ? 'Imported document' : title,
        content: sections.join('\n\n---\n\n'),
        type: NoteType.text,
        createdAt: now,
        updatedAt: now,
        tags: const ['imported'],
      );
      final repository = await NoteRepositoryProvider.instance();
      await repository.saveNote(note);
      if (!mounted) return;
      Navigator.of(context).pop(note);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = null;
        _importing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }

  Future<String> _extractText(String filename, Uint8List bytes) async {
    switch (p.extension(filename).toLowerCase()) {
      case '.txt':
      case '.md':
      case '.markdown':
        return utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '');
      case '.docx':
        return _extractDocx(bytes);
      case '.pdf':
        return _extractPdf(bytes);
      default:
        throw FormatException('Unsupported file type: ${p.extension(filename)}');
    }
  }

  String _extractPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final pages = <String>[];
      for (var i = 0; i < document.pages.count; i++) {
        final text = document.pages[i].extractText();
        if (text.trim().isNotEmpty) pages.add(text.trim());
      }
      return pages.join('\n\n');
    } finally {
      document.dispose();
    }
  }

  String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? documentFile;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        documentFile = file;
        break;
      }
    }
    if (documentFile == null) {
      throw const FormatException('This Word document is invalid or is not a .docx file.');
    }
    final xml = utf8.decode(documentFile.content as List<int>, allowMalformed: true);
    final withBreaks = xml
        .replaceAll(RegExp(r'</w:p\s*>'), '\n')
        .replaceAll(RegExp(r'</w:tr\s*>'), '\n')
        .replaceAll(RegExp(r'<w:tab\b[^>]*/>'), '\t')
        .replaceAll(RegExp(r'<w:br\b[^>]*/>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return _decodeXml(withBreaks)
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _decodeXml(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Import documents')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Icon(Icons.file_open_rounded, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Bring your documents into ORAH',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select one document or up to four files. Multiple files are combined, in selection order, into one editable note.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Supported formats', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FormatChip(label: 'Word (.docx)'),
                  _FormatChip(label: 'PDF (.pdf)'),
                  _FormatChip(label: 'Text (.txt)'),
                  _FormatChip(label: 'Markdown (.md)'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'PDFs with selectable text are supported. Scanned/image-only PDFs and legacy .doc files need conversion or OCR first.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_status != null) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_status!)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _importing ? null : _pickAndImport,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_importing ? 'Importing…' : 'Choose documents'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.description_outlined, size: 17),
        label: Text(label),
      );
}

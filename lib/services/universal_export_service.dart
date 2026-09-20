import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/note.dart';

enum NovaExportFormat { pdf, word, excel, text, markdown }

class UniversalExportService {
  const UniversalExportService();
  Future<File> export(Note note, NovaExportFormat format) async {
    final dir = await getTemporaryDirectory();
    final base = _safeName(note.title);
    late String ext;
    late List<int> bytes;
    switch (format) {
      case NovaExportFormat.pdf: ext='pdf'; bytes=await _pdf(note);
      case NovaExportFormat.word: ext='docx'; bytes=_docx(note);
      case NovaExportFormat.excel: ext='xlsx'; bytes=_xlsx(note);
      case NovaExportFormat.text: ext='txt'; bytes=utf8.encode(_text(note));
      case NovaExportFormat.markdown: ext='md'; bytes=utf8.encode(_markdown(note));
    }
    return File('${dir.path}/$base.$ext').writeAsBytes(bytes, flush:true);
  }
  String _safeName(String s) {
    final v=(s.trim().isEmpty?'NOVA Note':s.trim()).replaceAll(RegExp(r'[<>:"/\\|?*]'),'_');
    return v.substring(0,v.length.clamp(1,80));
  }
  List<String> _lines(String s)=>s.split(RegExp(r'\r?\n')).map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
  String _text(Note n)=>[
    if(n.title.trim().isNotEmpty)n.title.trim(),if(n.title.trim().isNotEmpty)'',
    if(n.type==NoteType.checklist)...n.checklistItems.map((e)=>(e.isDone?'☑ ':'☐ ')+e.text) else n.content,
    if(n.tags.isNotEmpty)'',if(n.tags.isNotEmpty)'Tags: ${n.tags.join(', ')}'
  ].join('\n');
  String _markdown(Note n)=>[
    if(n.title.trim().isNotEmpty)'# ${n.title.trim()}',if(n.title.trim().isNotEmpty)'',
    if(n.type==NoteType.checklist)...n.checklistItems.map((e)=>'- ['+(e.isDone?'x':' ')+'] '+e.text) else n.content,
    if(n.tags.isNotEmpty)'',if(n.tags.isNotEmpty)'Tags: ${n.tags.join(', ')}'
  ].join('\n');

  Future<List<int>> _pdf(Note n) async {
    final doc=pw.Document();
    final lines=n.type==NoteType.checklist?n.checklistItems.map((e)=>(e.isDone?'☑ ':'☐ ')+e.text).toList():_lines(n.content);
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(42),build:(_)=>[
      if(n.title.trim().isNotEmpty)pw.Text(n.title.trim(),style:pw.TextStyle(fontSize:24,fontWeight:pw.FontWeight.bold)),
      pw.SizedBox(height:18),...lines.map((e)=>pw.Padding(padding:const pw.EdgeInsets.only(bottom:8),child:pw.Text(e,style:const pw.TextStyle(fontSize:12)))),
      if(n.tags.isNotEmpty)pw.Text('Tags: ${n.tags.join(', ')}',style:const pw.TextStyle(fontSize:9))
    ]));
    return doc.save();
  }

  List<int> _docx(Note n){
    final ps=<String>[if(n.title.trim().isNotEmpty)_p(_xml(n.title.trim()),bold:true,size:32),..._lines(n.content).map((e)=>_p(_xml(e))),if(n.tags.isNotEmpty)_p(_xml('Tags: ${n.tags.join(', ')}'),size:18)];
    return _zip({
      '[Content_Types].xml':_types('application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml','/word/document.xml'),
      '_rels/.rels':_rels('http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument','word/document.xml'),
      'word/document.xml':'${_docStart()}${ps.join()}${_docEnd()}'
    });
  }

  List<int> _xlsx(Note n){
    final rows=<List<String>>[];
    if(n.type==NoteType.checklist){
      rows.add(['Done','Item']);
      for(final e in n.checklistItems)rows.add([e.isDone?'Yes':'No',e.text]);
    }else{
      rows.add(['Field','Value']);rows.add(['Title',n.title]);rows.add(['Content',n.content]);
      if(n.tags.isNotEmpty)rows.add(['Tags',n.tags.join(', ')]);
    }
    final out=<String>[];
    for(var r=0;r<rows.length;r++){
      final cells=<String>[];
      for(var c=0;c<rows[r].length;c++){final ref='${_col(c+1)}${r+1}';cells.add('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_xml(rows[r][c])}</t></is></c>');}
      out.add('<row r="${r+1}">${cells.join()}</row>');
    }
    return _zip({
      '[Content_Types].xml':_types('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml','/xl/workbook.xml','/xl/worksheets/sheet1.xml'),
      '_rels/.rels':_rels('http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument','xl/workbook.xml'),
      'xl/_rels/workbook.xml.rels':_rels('http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet','worksheets/sheet1.xml'),
      'xl/workbook.xml':'<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="NOVA Note" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/worksheets/sheet1.xml':'<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${out.join()}</sheetData></worksheet>'
    });
  }
  bool _checked(String s)=>s.startsWith('[x]')||s.startsWith('[X]')||s.startsWith('☑');
  String _col(int n){var r='';while(n>0){final x=(n-1)%26;r=String.fromCharCode(65+x)+r;n=(n-1)~/26;}return r;}
  String _xml(String s)=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&apos;');
  String _p(String s,{bool bold=false,int size=22})=>'<w:p><w:r><w:rPr>${bold?'<w:b/>':''}<w:sz w:val="$size"/></w:rPr><w:t xml:space="preserve">$s</w:t></w:r></w:p>';
  String _docStart()=> '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>';
  String _docEnd()=>'<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>';
  String _types(String main,String part,[String? part2])=>'<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="$part" ContentType="$main"/>${part2==null?'':'<Override PartName="$part2" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'}</Types>';
  String _rels(String type,String target)=>'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="$type" Target="$target"/></Relationships>';
  List<int> _zip(Map<String,String> files){final a=Archive();for(final e in files.entries){final b=utf8.encode(e.value);a.addFile(ArchiveFile(e.key,b.length,b));}return ZipEncoder().encode(a)??<int>[];}
}

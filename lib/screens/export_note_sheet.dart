import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../services/universal_export_service.dart';
import '../services/orah_feature_gate.dart';
import '../services/orah_premium_gate.dart';

class ExportNoteSheet extends StatefulWidget {
  const ExportNoteSheet({super.key, required this.note});
  final Note note;
  @override State<ExportNoteSheet> createState()=>_ExportNoteSheetState();
}
class _ExportNoteSheetState extends State<ExportNoteSheet>{
  bool _busy=false;
  Future<void> _export(NovaExportFormat format) async{
    setState(()=>_busy=true);
    try{
      final file=await const UniversalExportService().export(widget.note,format);
      if(!mounted)return;
      await Share.shareXFiles([XFile(file.path)],subject:'ORAH — ${widget.note.title}',text:'Exported from ORAH');
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Export failed: $e')));
    }finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>SafeArea(child:Padding(
    padding:const EdgeInsets.fromLTRB(20,8,20,24),
    child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Export note',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      const Text('Choose a format. ORAH creates a portable file and opens the system share sheet.'),
      const SizedBox(height:16),
      if(_busy)const LinearProgressIndicator(),
      _tile(Icons.picture_as_pdf_outlined,'PDF','Printable document',NovaExportFormat.pdf),
      _tile(Icons.description_outlined,'Word (.docx)','Editable Microsoft Word document',NovaExportFormat.word),
      _tile(Icons.table_chart_outlined,'Excel (.xlsx)','Spreadsheet; checklists become rows',NovaExportFormat.excel),
      _tile(Icons.text_snippet_outlined,'Text (.txt)','Simple universal text',NovaExportFormat.text),
      _tile(Icons.code_outlined,'Markdown (.md)','Portable Markdown',NovaExportFormat.markdown),
    ])));
  Widget _tile(IconData icon,String title,String subtitle,NovaExportFormat f) {
    final premium = f == NovaExportFormat.pdf || f == NovaExportFormat.word || f == NovaExportFormat.excel;
    return ListTile(
      leading: Icon(icon),
      title: Row(children: [Expanded(child: Text(title)), if (premium) const Icon(Icons.workspace_premium_rounded, size: 18)]),
      subtitle: Text(subtitle),
      enabled: !_busy,
      onTap: () async {
        if (premium && !await OrahPremiumGate.check(context, OrahFeature.advancedExport)) return;
        await _export(f);
      },
    );
  }
}

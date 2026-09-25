import 'package:flutter/material.dart';

import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../services/orah_feature_gate.dart';
import '../services/orah_premium_gate.dart';
import 'note_editor_screen.dart';

class OrahTemplatesScreen extends StatelessWidget {
  const OrahTemplatesScreen({super.key});

  static const templates = <_OrahTemplate>[
    _OrahTemplate('Meeting Notes', 'Capture decisions, owners and follow-ups.', 'Agenda\n\nDecisions\n\nAction items\n\nNext meeting:', false),
    _OrahTemplate('Daily Plan', 'Plan the day without overthinking it.', 'Top priorities\n\n1. \n2. \n3. \n\nNotes\n\nWin of the day:', false),
    _OrahTemplate('Shopping List', 'A clean reusable shopping note.', 'Groceries\n\nHousehold\n\nOther:', false),
    _OrahTemplate('Project Brief', 'Turn a rough idea into an executable brief.', 'Project\n\nObjective\n\nScope\n\nMilestones\n\nRisks\n\nOwners\n\nNext actions:', true),
    _OrahTemplate('Travel Plan', 'Keep a trip in one compact note.', 'Destination\n\nDates\n\nTransport\n\nStay\n\nPlaces\n\nBookings\n\nPacking\n\nBudget:', true),
    _OrahTemplate('Travel Diary', 'Capture an offline trip memory as you go.', 'Date\n\nLocation\n\nHighlights\n\nPhotos\n[Add photos here]', false),
    _OrahTemplate('Journal', 'Mood check-in plus open-ended writing.', 'Mood: \n\nFree write\n\n', false),
    _OrahTemplate('Recipe', 'Keep ingredients, method and notes together.', 'Ingredients\n\n- \n- \n- \n\nSteps\n\n1. \n2. \n3. \n\nNotes\n', false),
    _OrahTemplate('Book Notes', 'Save ideas and memorable passages from a book.', 'Title: \nAuthor: \n\nKey ideas\n\n- \n- \n- \n\nQuotes\n\n- \n', false),
    _OrahTemplate('Expense Tracker', 'Record spending and keep a running total.', 'Date\n\nItem\n\nAmount\n\nTotal\n', false),
    _OrahTemplate('Workout Log', 'Track exercises, sets and training notes.', 'Exercise\n\nSets\n\nNotes\n', false),
  ];

  Future<void> _use(BuildContext context, _OrahTemplate template) async {
    if (template.premium &&
        !await OrahPremiumGate.check(context, OrahFeature.premiumTemplates)) {
      return;
    }
    final repository = await NoteRepositoryProvider.instance();
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(
        repository: repository,
        initialType: NoteType.text,
        initialTitle: template.title,
        initialContent: template.content,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = templates[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: CircleAvatar(
                child: Icon(item.premium ? Icons.workspace_premium_rounded : Icons.description_outlined),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (item.premium)
                    Text('PRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                ],
              ),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _use(context, item),
            ),
          );
        },
      ),
    );
  }
}

class _OrahTemplate {
  const _OrahTemplate(this.title, this.subtitle, this.content, this.premium);
  final String title;
  final String subtitle;
  final String content;
  final bool premium;
}

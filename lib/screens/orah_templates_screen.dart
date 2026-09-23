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
    _OrahTemplate('Expense Log', 'Record spending with useful context.', 'Date\n\nCategory\n\nAmount\n\nPayment method\n\nNotes:', true),
    _OrahTemplate('Journal', 'A private daily reflection starter.', 'Today I feel...\n\nWhat happened?\n\nWhat mattered?\n\nWhat I learned\n\nTomorrow I want to:', true),
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

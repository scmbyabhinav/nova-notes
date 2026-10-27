
import 'package:flutter/material.dart';

class NovaQuickActions extends StatelessWidget {
  const NovaQuickActions({
    super.key,
    required this.onNewNote,
    required this.onNewChecklist,
  });

  final VoidCallback onNewNote;
  final VoidCallback onNewChecklist;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onNewNote,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Quick note'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onNewChecklist,
            icon: const Icon(Icons.check_box_outlined),
            label: const Text('Checklist'),
          ),
        ),
      ],
    );
  }
}

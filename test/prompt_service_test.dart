import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/services/prompt_service.dart';

void main() {
  group('PromptService', () {
    test('contains at least 30 reflective prompts across themes', () {
      expect(PromptService.prompts.length, greaterThanOrEqualTo(30));
      expect(
        PromptService.prompts.map((prompt) => prompt.category).toSet().length,
        greaterThanOrEqualTo(5),
      );
      expect(
        PromptService.prompts.every((prompt) => prompt.text.trim().isNotEmpty),
        isTrue,
      );
    });

    test('daily prompt is stable within the same calendar date', () {
      final first = PromptService.instance.getPromptOfDay(
        date: DateTime(2026, 10, 3, 8, 15),
      );
      final later = PromptService.instance.getPromptOfDay(
        date: DateTime(2026, 10, 3, 22, 45),
      );
      expect(first.text, later.text);
      expect(first.category, later.category);
    });

    test('daily prompt advances with the calendar day', () {
      final prompts = PromptService.prompts;
      final first = PromptService.instance.getPromptOfDay(date: DateTime(2026, 10, 3));
      final next = PromptService.instance.getPromptOfDay(date: DateTime(2026, 10, 4));
      expect(next, isNot(same(first)));
      expect(prompts, contains(first));
      expect(prompts, contains(next));
    });

    test('random prompt is one of the curated prompts', () {
      expect(PromptService.prompts, contains(PromptService.instance.getRandomPrompt()));
    });
  });
}

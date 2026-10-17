import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/data/reflection_prompt_translations.dart';
import 'package:orah_notes/services/prompt_service.dart';

void main() {
  group('Reflection prompt translations', () {
    test('contains all 150 prompts in each of the 13 non-English locales', () {
      expect(PromptService.prompts, hasLength(150));
      expect(reflectionPromptTranslations.keys.toSet(), {
        'ar', 'de', 'es', 'fr', 'he', 'hi', 'id',
        'it', 'ja', 'ko', 'pt', 'tr', 'zh',
      });

      final englishPrompts =
          PromptService.prompts.map((prompt) => prompt.text).toSet();
      expect(englishPrompts, hasLength(150));

      for (final locale in reflectionPromptTranslations.keys) {
        final translations = reflectionPromptTranslations[locale]!;
        expect(translations.keys.toSet(), englishPrompts, reason: locale);
        expect(
          translations.values.every((value) => value.trim().isNotEmpty),
          isTrue,
          reason: '$locale contains an empty translation',
        );
      }
    });

    test('uses the selected locale and falls back to English when unavailable', () {
      const prompt = ReflectionPrompt(
        text: 'What is one small thing that brought you comfort today?',
        category: 'Gratitude',
      );

      expect(prompt.localizedText('es'), isNot(prompt.text));
      expect(prompt.localizedText('en'), prompt.text);
      expect(prompt.localizedText('unknown'), prompt.text);
    });
  });
}

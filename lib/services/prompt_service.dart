import 'dart:math';

/// A thoughtful question grouped into a theme for daily journaling.
class ReflectionPrompt {
  const ReflectionPrompt({required this.text, required this.category});

  final String text;
  final String category;
}

class PromptService {
  PromptService._();

  static final PromptService instance = PromptService._();
  final Random _random = Random();

  static const List<ReflectionPrompt> prompts = [
    ReflectionPrompt(text: 'What is one small thing that brought you comfort today?', category: 'Gratitude'),
    ReflectionPrompt(text: 'Who made your day a little better, and how?', category: 'Gratitude'),
    ReflectionPrompt(text: 'What part of your life do you sometimes take for granted?', category: 'Gratitude'),
    ReflectionPrompt(text: 'What ordinary moment from this week would you like to remember?', category: 'Gratitude'),
    ReflectionPrompt(text: 'What strength in yourself are you grateful to have developed?', category: 'Gratitude'),
    ReflectionPrompt(text: 'What is something beautiful you noticed recently that you might otherwise have missed?', category: 'Mindfulness'),
    ReflectionPrompt(text: 'What feeling has been asking for your attention today?', category: 'Mindfulness'),
    ReflectionPrompt(text: 'When did you feel most present in the moment this week?', category: 'Mindfulness'),
    ReflectionPrompt(text: 'What can you let be unfinished for now?', category: 'Mindfulness'),
    ReflectionPrompt(text: 'What would a gentler pace look like for you tomorrow?', category: 'Mindfulness'),
    ReflectionPrompt(text: 'What did a recent challenge teach you about yourself?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'Which belief about yourself are you ready to question?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'What is one brave, small step you could take toward something meaningful?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'Where have you grown in a way that your past self would appreciate?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'What mistake could you treat as information rather than a verdict?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'What does success mean to you when nobody else is watching?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'What boundary would help you protect your time or energy?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'What would you try if you trusted yourself to learn along the way?', category: 'Personal Growth'),
    ReflectionPrompt(text: 'What conversation has stayed with you, and why?', category: 'Relationships'),
    ReflectionPrompt(text: 'Who might need to hear appreciation from you?', category: 'Relationships'),
    ReflectionPrompt(text: 'When do you feel most understood by another person?', category: 'Relationships'),
    ReflectionPrompt(text: 'What is one way you could listen more generously this week?', category: 'Relationships'),
    ReflectionPrompt(text: 'Which relationship deserves more intentional time from you?', category: 'Relationships'),
    ReflectionPrompt(text: 'What do you wish people understood about you more easily?', category: 'Relationships'),
    ReflectionPrompt(text: 'What is something you need to forgive yourself for, even if slowly?', category: 'Self-Compassion'),
    ReflectionPrompt(text: 'How would you speak to a friend facing the same worry you have?', category: 'Self-Compassion'),
    ReflectionPrompt(text: 'What expectation could you release to make room for peace?', category: 'Self-Compassion'),
    ReflectionPrompt(text: 'What have you handled lately that deserves more credit?', category: 'Self-Compassion'),
    ReflectionPrompt(text: 'What does rest look like when you stop trying to earn it?', category: 'Self-Compassion'),
    ReflectionPrompt(text: 'What is taking up the most space in your mind right now?', category: 'Clarity'),
    ReflectionPrompt(text: 'What matters most to you in this season of life?', category: 'Clarity'),
    ReflectionPrompt(text: 'What is one thing you can influence today, and one thing you can release?', category: 'Clarity'),
    ReflectionPrompt(text: 'What would make tomorrow feel meaningful, even if it is imperfect?', category: 'Clarity'),
    ReflectionPrompt(text: 'Which commitment still reflects your values, and which may need revisiting?', category: 'Clarity'),
    ReflectionPrompt(text: 'What are you curious to explore simply because it interests you?', category: 'Possibility'),
    ReflectionPrompt(text: 'If you had an extra hour with no obligations, how would you use it?', category: 'Possibility'),
    ReflectionPrompt(text: 'What possibility feels exciting even though it is not fully mapped out?', category: 'Possibility'),
    ReflectionPrompt(text: 'What would you like your future self to thank you for starting today?', category: 'Possibility'),
    ReflectionPrompt(text: 'What is one experience you want to make more room for this month?', category: 'Possibility'),
    ReflectionPrompt(text: 'What did today reveal about what you need more—or less—of?', category: 'Daily Review'),
    ReflectionPrompt(text: 'What is one moment from today you want to carry into tomorrow?', category: 'Daily Review'),
  ];

  /// Returns a prompt that is stable for the whole local calendar day.
  ReflectionPrompt getPromptOfDay({DateTime? date}) {
    final now = date ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final epoch = DateTime(2024, 1, 1);
    final dayIndex = day.difference(epoch).inDays.abs();
    return prompts[dayIndex % prompts.length];
  }

  /// Returns a randomly selected reflective prompt.
  ReflectionPrompt getRandomPrompt() => prompts[_random.nextInt(prompts.length)];
}

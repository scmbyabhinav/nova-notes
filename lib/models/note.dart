class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  final String id;
  final String text;
  final bool isDone;

  ChecklistItem copyWith({String? text, bool? isDone}) =>
      ChecklistItem(id: id, text: text ?? this.text, isDone: isDone ?? this.isDone);

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'isDone': isDone};

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: map['text'] as String? ?? '',
        isDone: map['isDone'] as bool? ?? false,
      );
}

enum NoteType {
  text,
  checklist,
  voice,
  image,
  drawing,
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.tags = const [],
    this.attachments = const [],
    this.checklistItems = const [],
    this.color,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isLocked = false,
  });

  final String id;
  final String title;
  final String content;
  final NoteType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final List<String> tags;
  final List<String> attachments;
  final List<ChecklistItem> checklistItems;
  final int? color;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isLocked;

  int get completedChecklistItems =>
      checklistItems.where((item) => item.isDone).length;

  double get checklistProgress => checklistItems.isEmpty
      ? 0
      : completedChecklistItems / checklistItems.length;

  Note copyWith({
    String? title,
    String? content,
    NoteType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    bool clearFolder = false,
    List<String>? tags,
    List<String>? attachments,
    List<ChecklistItem>? checklistItems,
    int? color,
    bool clearColor = false,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isLocked,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      checklistItems: checklistItems ?? this.checklistItems,
      color: clearColor ? null : (color ?? this.color),
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
    this.dueAt,
  });

  final String id;
  final String text;
  final bool isDone;
  final DateTime? dueAt;

  ChecklistItem copyWith({String? text, bool? isDone, DateTime? dueAt, bool clearDueAt = false}) =>
      ChecklistItem(id: id, text: text ?? this.text, isDone: isDone ?? this.isDone, dueAt: clearDueAt ? null : (dueAt ?? this.dueAt));

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'isDone': isDone, 'dueAt': dueAt?.toIso8601String()};

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: map['text'] as String? ?? '',
        isDone: map['isDone'] as bool? ?? false,
        dueAt: map['dueAt'] == null ? null : DateTime.tryParse(map['dueAt'] as String),
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
    this.isTrashed = false,
    this.dueAt,
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
  final bool isTrashed;
  final DateTime? dueAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'folderId': folderId,
        'tags': tags,
        'attachments': attachments,
        'checklistItems': checklistItems.map((item) => item.toMap()).toList(),
        'color': color,
        'isPinned': isPinned,
        'isFavorite': isFavorite,
        'isArchived': isArchived,
        'isLocked': isLocked,
        'isTrashed': isTrashed,
        'dueAt': dueAt?.toIso8601String(),
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        type: NoteType.values.firstWhere(
          (value) => value.name == map['type'],
          orElse: () => NoteType.text,
        ),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
        folderId: map['folderId'] as String?,
        tags: List<String>.from(map['tags'] as List? ?? const []),
        attachments: List<String>.from(map['attachments'] as List? ?? const []),
        checklistItems: (map['checklistItems'] as List? ?? const [])
            .map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList(),
        color: map['color'] as int?,
        isPinned: map['isPinned'] as bool? ?? false,
        isFavorite: map['isFavorite'] as bool? ?? false,
        isArchived: map['isArchived'] as bool? ?? false,
        isLocked: map['isLocked'] as bool? ?? false,
        isTrashed: map['isTrashed'] as bool? ?? false,
        dueAt: map['dueAt'] == null ? null : DateTime.tryParse(map['dueAt'] as String),
      );

  int get completedChecklistItems =>
      checklistItems.where((item) => item.isDone).length;

  bool get hasContent => title.trim().isNotEmpty || content.trim().isNotEmpty || attachments.isNotEmpty || checklistItems.isNotEmpty;

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
    bool? isTrashed,
    DateTime? dueAt,
    bool clearDueAt = false,
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
      isTrashed: isTrashed ?? this.isTrashed,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
    );
  }
}

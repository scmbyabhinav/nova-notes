class NoteFolder {
  const NoteFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.iconCodePoint,
    this.color,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int? iconCodePoint;
  final int? color;
}

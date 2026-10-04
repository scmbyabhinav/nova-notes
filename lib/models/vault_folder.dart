class VaultFolder {
  const VaultFolder({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory VaultFolder.fromMap(Map<String, dynamic> map) => VaultFolder(
        id: map['id'] as String,
        name: map['name'] as String,
      );
}

import 'dart:convert';

/// A local-only ORAH Connect reminder. It never represents an auto-published post.
class ScheduledPost {
  const ScheduledPost({
    required this.id,
    required this.platform,
    required this.caption,
    required this.scheduledAt,
    this.imagePath,
    this.completed = false,
  });

  final String id;
  final String platform;
  final String caption;
  final DateTime scheduledAt;
  final String? imagePath;
  final bool completed;

  Map<String, Object?> toJson() => {
        'id': id,
        'platform': platform,
        'caption': caption,
        'scheduledAt': scheduledAt.toIso8601String(),
        if (imagePath != null) 'imagePath': imagePath,
        'completed': completed,
      };

  factory ScheduledPost.fromJson(Map<String, Object?> json) => ScheduledPost(
        id: json['id'] as String,
        platform: json['platform'] as String,
        caption: json['caption'] as String,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        imagePath: json['imagePath'] as String?,
        completed: json['completed'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  factory ScheduledPost.decode(String value) =>
      ScheduledPost.fromJson(jsonDecode(value) as Map<String, Object?>);

  ScheduledPost copyWith({bool? completed}) => ScheduledPost(
        id: id,
        platform: platform,
        caption: caption,
        scheduledAt: scheduledAt,
        imagePath: imagePath,
        completed: completed ?? this.completed,
      );
}

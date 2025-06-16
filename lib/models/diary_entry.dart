class DiaryEntry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String emoji;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.emoji,
    required this.createdAt,
    this.updatedAt,
  });

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      emoji: map['emoji'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'])
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

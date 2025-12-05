class CardModel {
  final int? id;
  String title;
  String content;
  List<String> imageUrls;
  bool isMarked;
  bool isCompleted; // 新增：完成状态
  
  String groupName;
  String tags;
  DateTime createdAt;

  String reminderType; 
  String reminderValue; 
  DateTime? lastReviewed;

  CardModel({
    this.id,
    required this.title,
    required this.content,
    this.imageUrls = const [],
    this.isMarked = false,
    this.isCompleted = false, // 默认未完成
    this.groupName = '默认清单',
    this.tags = '',
    required this.createdAt,
    this.reminderType = 'none',
    this.reminderValue = '',
    this.lastReviewed,
  });

  DateTime? get nextReminderTime {
    if (reminderType == 'none') return null;
    if (reminderType == 'specific' && reminderValue.isNotEmpty) {
      try { return DateTime.parse(reminderValue); } catch (e) { return null; }
    }
    if (reminderType == 'periodic' && reminderValue.isNotEmpty && lastReviewed != null) {
      final days = int.tryParse(reminderValue) ?? 0;
      return lastReviewed!.add(Duration(days: days));
    }
    return null;
  }

  // 只有在【未完成】且【已过期】时才算 isDue
  bool get isDue {
    if (isCompleted) return false; // 完成了就不催了
    final next = nextReminderTime;
    if (next == null) return false;
    return DateTime.now().isAfter(next);
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      title: json['title'],
      content: json['content'] ?? '',
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      isMarked: json['is_marked'] ?? false,
      isCompleted: json['is_completed'] ?? false, // 读字段
      groupName: json['group_name'] ?? '默认清单',
      tags: json['tags'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      reminderType: json['reminder_type'] ?? 'none',
      reminderValue: json['reminder_value'] ?? '',
      lastReviewed: json['last_reviewed'] != null ? DateTime.parse(json['last_reviewed']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'is_marked': isMarked,
      'is_completed': isCompleted, // 写字段
      'group_name': groupName,
      'tags': tags,
      'reminder_type': reminderType,
      'reminder_value': reminderValue,
    };
  }
}
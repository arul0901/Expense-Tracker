class NotificationModel {
  final String id;
  final String recipientUserId;
  final String actorUserId;
  final String? roomId;
  final String? eventId;
  final String type;
  final String title;
  final String message;
  final String entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.actorUserId,
    this.roomId,
    this.eventId,
    required this.type,
    required this.title,
    required this.message,
    required this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      recipientUserId: json['recipient_user_id'],
      actorUserId: json['actor_user_id'],
      roomId: json['room_id'],
      eventId: json['event_id'],
      type: json['type'],
      title: json['title'],
      message: json['message'],
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

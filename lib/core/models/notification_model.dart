// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum to categorize notifications for filtering or display logic.
enum NotificationType { order_update, promotion, account_alert, general }

/// Represents a notification document, typically stored in a subcollection
/// under a user: `/users/{userId}/notifications/{notificationId}`.
class NotificationModel extends Equatable {
  /// The unique ID of the notification document.
  final String id;

  /// The title of the notification.
  final String title;

  /// The main content/body of the notification.
  final String body;

  /// A flag to track if the user has seen the notification.
  final bool isRead;

  /// The category of the notification.
  final NotificationType type;

  /// A map of data for handling actions, like deep-linking into the app.
  /// For example: `{'orderId': '12345'}` to open a specific order screen.
  final Map<String, dynamic>? metadata;

  /// The timestamp of when the notification was created.
  final Timestamp createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.type,
    this.metadata,
    required this.createdAt,
  });

  /// Creates a `NotificationModel` instance from a Firestore document snapshot.
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      type: NotificationType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => NotificationType.general,
      ),
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts this `NotificationModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'isRead': isRead,
      'type': type.name,
      'metadata': metadata,
      'createdAt': createdAt,
    };
  }

  /// Creates a copy of this notification with updated fields.
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    bool? isRead,
    NotificationType? type,
    Map<String, dynamic>? metadata,
    Timestamp? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, title, isRead, type, createdAt];
}
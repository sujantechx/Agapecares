// lib/models/review_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a review for a completed order in the `reviews` collection.
class ReviewModel extends Equatable {
  /// The unique ID of the review document.
  final String id;
  /// The ID of the order this review is for.
  final String orderId;
  /// The UID of the customer who wrote the review.
  final String userId;
  /// The UID of the worker who was rated.
  final String workerId;
  /// The star rating, from 1 to 5.
  final int rating;
  /// The optional text comment from the customer.
  final String? comment;
  /// Timestamp when the review was submitted.
  final Timestamp createdAt;

  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.workerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReviewModel(
      id: doc.id,
      orderId: data['orderId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      workerId: data['workerId'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'userId': userId,
      'workerId': workerId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [id, orderId, userId, workerId, rating];
}
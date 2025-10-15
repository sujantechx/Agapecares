// lib/models/worker_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum for the professional status of a worker.
enum WorkerStatus { pending, approved, disabled }

/// Represents a worker's professional profile in the `workers` collection.
/// This data is linked to a `UserModel` by sharing the same UID.
class WorkerModel extends Equatable {
  /// The UID, linking this profile to a document in the `users` collection.
  final String uid;

  /// List of `serviceId`s that this worker is qualified to perform.
  final List<String> skills;

  /// The worker's current professional status (e.g., pending approval).
  final WorkerStatus status;

  /// The worker's average rating from all completed jobs.
  final double ratingAvg;

  /// The total number of ratings the worker has received.
  final int ratingCount;

  /// Timestamp of when the worker profile was created.
  final Timestamp onboardedAt;

  const WorkerModel({
    required this.uid,
    this.skills = const [],
    required this.status,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    required this.onboardedAt,
  });

  /// Creates a `WorkerModel` instance from a Firestore document snapshot.
  factory WorkerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WorkerModel(
      uid: doc.id,
      skills: List<String>.from(data['skills'] ?? []),
      status: WorkerStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => WorkerStatus.pending,
      ),
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      onboardedAt: data['onboardedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts this `WorkerModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'skills': skills,
      'status': status.name,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'onboardedAt': onboardedAt,
    };
  }

  /// Creates a copy of this worker profile with updated fields.
  WorkerModel copyWith({
    String? uid,
    List<String>? skills,
    WorkerStatus? status,
    double? ratingAvg,
    int? ratingCount,
    Timestamp? onboardedAt,
  }) {
    return WorkerModel(
      uid: uid ?? this.uid,
      skills: skills ?? this.skills,
      status: status ?? this.status,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      onboardedAt: onboardedAt ?? this.onboardedAt,
    );
  }

  @override
  List<Object?> get props => [uid, skills, status, ratingAvg, ratingCount, onboardedAt];
}
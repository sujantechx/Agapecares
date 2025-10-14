// lib/shared/models/worker_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerModel {
  final String id;
  final String name;
  final double rating;
  final double earnings;
  final bool isAvailable;

  WorkerModel({
    required this.id,
    required this.name,
    required this.rating,
    required this.earnings,
    required this.isAvailable,
  });

  factory WorkerModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return WorkerModel(
      id: documentId,
      name: data['name'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      earnings: (data['earnings'] ?? 0.0).toDouble(),
      isAvailable: data['isAvailable'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'rating': rating,
      'earnings': earnings,
      'isAvailable': isAvailable,
    };
  }

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    return WorkerModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rating': rating,
      'earnings': earnings,
      'isAvailable': isAvailable,
    };
  }
}

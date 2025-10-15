// lib/models/audit_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents an entry in the `audit_logs` collection.
/// These logs track important admin actions for security and accountability.
/// **WARNING: This collection should ONLY be writable from a trusted server environment.**
class AuditLogModel extends Equatable {
/// The unique ID of the log entry.
final String id;

/// The UID of the admin who performed the action.
final String actorId;

/// A snapshot of the admin's name for easy display in logs.
final String actorName;

/// A short, machine-readable string describing the action (e.g., "update_order_status").
final String action;

/// The collection that was affected by the action (e.g., "orders").
final String targetCollection;

/// The ID of the document that was affected.
final String targetDocId;

/// An optional, human-readable reason for the action provided by the admin.
final String? reason;

/// A map containing the state of the data 'before' and 'after' the change.
final Map<String, dynamic>? changes;

/// The timestamp of when the action occurred.
final Timestamp timestamp;

const AuditLogModel({
required this.id,
required this.actorId,
required this.actorName,
required this.action,
required this.targetCollection,
required this.targetDocId,
this.reason,
this.changes,
required this.timestamp,
});

/// Creates an `AuditLogModel` instance from a Firestore document snapshot.
factory AuditLogModel.fromFirestore(DocumentSnapshot doc) {
final data = doc.data() as Map<String, dynamic>? ?? {};
return AuditLogModel(
id: doc.id,
actorId: data['actorId'] as String? ?? '',
actorName: data['actorName'] as String? ?? '',
action: data['action'] as String? ?? 'unknown_action',
targetCollection: data['targetCollection'] as String? ?? '',
targetDocId: data['targetDocId'] as String? ?? '',
reason: data['reason'] as String?,
changes: data['changes'] != null ? Map<String, dynamic>.from(data['changes']) : null,
timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
);
}

/// Converts this `AuditLogModel` instance into a map for storing in Firestore.
Map<String, dynamic> toFirestore() {
return {
'actorId': actorId,
'actorName': actorName,
'action': action,
'targetCollection': targetCollection,
'targetDocId': targetDocId,
'reason': reason,
'changes': changes,
'timestamp': timestamp,
};
}

@override
List<Object?> get props => [id, actorId, action, targetDocId, timestamp];
}
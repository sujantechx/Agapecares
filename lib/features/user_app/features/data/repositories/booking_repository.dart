import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';


/// BookingRepository stores booking/order documents in Firestore under `bookings`.
class BookingRepository {
  final FirebaseFirestore _firestore;

  BookingRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a booking document in Firestore. Returns the generated document id.
  Future<String> createBooking(OrderModel order) async {
    final docRef = await _firestore.collection('bookings').add(order.toFirestore());
    try { await docRef.update({'remoteId': docRef.id}); } catch (_) {}
    return docRef.id;
  }

  /// Fetch bookings for a user
  Future<List<OrderModel>> fetchBookingsForUser(String userId) async {
    final snap = await _firestore.collection('bookings').where('userId', isEqualTo: userId).get();
    return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';


/// BookingRepository stores booking/order documents in Firestore under top-level `bookings` collection.
class BookingRepository {
  final FirebaseFirestore _firestore;

  BookingRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a booking document in Firestore under top-level `bookings`. Returns the generated document id.
  Future<String> createBooking(OrderModel order) async {
    if (order.userId.isEmpty) {
      throw Exception('Missing userId on order when creating booking');
    }
    final bookingsCol = _firestore.collection('bookings');
    final bookingMap = {
      'orderOwner': order.userId,
      'userId': order.userId,
      'orderId': order.id,
      'orderNumber': order.orderNumber,
      'items': order.items.map((i) => i.toMap()).toList(),
      'addressSnapshot': order.addressSnapshot,
      'subtotal': order.subtotal,
      'discount': order.discount,
      'tax': order.tax,
      'totalAmount': order.total, // match security rules expected field
      'orderStatus': order.orderStatus.name,
      'paymentStatus': order.paymentStatus.name,
      'scheduledAt': order.scheduledAt,
      'createdAt': FieldValue.serverTimestamp(),
      // do not set client timestamps or orderNumber here
    };
    final docRef = await bookingsCol.add(bookingMap);
    try { await docRef.update({'remoteId': docRef.id}); } catch (_) {}
    return docRef.id;
  }

  /// Fetch bookings for a user
  Future<List<OrderModel>> fetchBookingsForUser(String userId) async {
    final snap = await _firestore.collection('bookings').where('orderOwner', isEqualTo: userId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
  }
}


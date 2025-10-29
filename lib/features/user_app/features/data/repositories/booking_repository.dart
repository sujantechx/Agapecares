// This repository is deprecated: the top-level `bookings` collection has been
// removed from the security rules and client flows. Keeping this file in the
// codebase for reference, but all methods throw to prevent accidental usage.

import 'package:agapecares/core/models/order_model.dart';

class BookingRepository {
  BookingRepository({dynamic firestore}) {
    // Intentionally no-op. The constructor accepts an optional firestore
    // parameter for compatibility but this repository should not be used.
  }

  Future<String> createBooking(OrderModel order) async {
    throw Exception('BookingRepository.createBooking is disabled: the top-level `bookings` collection was removed. Persist orders under users/{uid}/orders or manage via trusted backend.');
  }

  Future<List<OrderModel>> fetchBookingsForUser(String userId) async {
    throw Exception('BookingRepository.fetchBookingsForUser is disabled: the top-level `bookings` collection was removed.');
  }
}

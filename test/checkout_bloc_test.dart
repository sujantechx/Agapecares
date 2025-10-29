import 'package:flutter_test/flutter_test.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/bloc/checkout_bloc.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/model/payment_models.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/bloc/checkout_event.dart';

import 'package:agapecares/features/user_app/features/payment_gateway/repository/razorpay_payment_repository.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/repository/cod_payment_repository.dart';
import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository.dart';
import 'package:agapecares/features/user_app/features/data/repositories/booking_repository.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'package:agapecares/core/models/cart_item_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;

// Fake implementations
class FakeOrderRepo implements user_orders_repo.OrderRepository {
  bool created = false;
  bool uploaded = false;

  @override
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true, String? userId}) async {
    // For tests we mark created when this method is invoked.
    created = true;
  }

  @override
  Future<String> generateOrderNumber() async => 'TESTORDER00100';

  @override
  Future<String> uploadOrder(OrderModel localOrder) async {
    uploaded = true;
    return 'order_test_1';
  }

  @override
  Future<List<OrderModel>> fetchOrdersForUser(String userId) async => [];

  @override
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId) async => [];

  @override
  Stream<List<OrderModel>> streamOrdersForWorker(String workerId) async* {
    yield <OrderModel>[];
  }

  @override
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters}) async => [];

  @override
  Future<void> dedupeRemoteOrdersForUser({required String userId, required String orderNumber}) async {
    // no-op in tests
    return;
  }

  @override
  Future<bool> submitRatingForOrder({required OrderModel order, required double serviceRating, double? workerRating, String? review}) async {
    return true;
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    // no-op for tests
    return;
  }
}

class FakeRazorpay extends RazorpayPaymentRepository {
  final PaymentResult result;
  FakeRazorpay(this.result) : super(backendCreateOrderUrl: 'http://example');

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async => result;

  @override
  void dispose() {}
}

class FakeCod implements CodPaymentRepository {
  final PaymentResult result;
  FakeCod(this.result);

  @override
  Future<PaymentResult> processCod(PaymentRequest request) async => result;
}

class FakeCartRepo implements CartRepository {
  bool cleared = false;
  @override
  Future<void> clearCart() async { cleared = true; }
  @override
  Future<List<CartItemModel>> getCartItems() async => [];
  @override
  Future<void> addItemToCart(CartItemModel item) async {}
  @override
  Future<void> removeItemFromCart(String cartItemId) async {}
  @override
  Future<void> updateItemQuantity(String cartItemId, int quantity) async {}

  // Methods declared as concrete in the interface must also be provided when using 'implements'
  @override
  Future<void> addCartItem(String userId, CartItemModel item) async {}
  @override
  Future<void> removeCartItem(String userId, String itemId) async {}
}

class FakeBookingRepo implements BookingRepository {
  bool created = false;
  @override
  Future<String> createBooking(OrderModel order) async { created = true; return 'booking_1'; }

  @override
  Future<List<OrderModel>> fetchBookingsForUser(String userId) async => [];
}

// Minimal fake Firestore classes to avoid initializing Firebase in tests
class FakeDocumentSnapshot {
  final bool exists;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this.exists, [this._data]);
  Map<String, dynamic>? data() => _data;
}

class FakeDocumentReference {
  final String id;
  FakeDocumentReference(this.id);
  Future<void> update(Map<String, dynamic> data) async {}
  Future<void> set(Map<String, dynamic> data, {SetOptions? options}) async {}
  Future<FakeDocumentSnapshot> get() async => FakeDocumentSnapshot(false, {});
  FakeCollectionReference collection(String name) => FakeCollectionReference('$id/$name');
}

class FakeCollectionReference {
  final String path;
  static int _counter = 0;
  FakeCollectionReference(this.path);
  FakeDocumentReference doc([String? id]) {
    return FakeDocumentReference(id ?? 'doc_${_counter++}');
  }

  Future<FakeDocumentReference> add(Map<String, dynamic> data) async {
    final created = this.doc();
    return created;
  }

  FakeQuery where(String field, {required Object isEqualTo}) => FakeQuery(path);
  FakeQuery orderBy(String field, {bool descending = false}) => FakeQuery(path);
  Future<FakeQuerySnapshot> get() async => FakeQuerySnapshot([]);
}

class FakeQuery {
  final String path;
  FakeQuery(this.path);
  FakeQuery where(String field, {required Object isEqualTo}) => this;
  FakeQuery orderBy(String field, {bool descending = false}) => this;
  Future<FakeQuerySnapshot> get() async => FakeQuerySnapshot([]);
}

class FakeQuerySnapshot {
  final List<FakeQueryDocumentSnapshot> docs;
  FakeQuerySnapshot(this.docs);
}

class FakeQueryDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this.id, this._data);
  Map<String, dynamic> data() => _data;
}

class FakeFirestoreInstance {
  FakeCollectionReference collection(String name) => FakeCollectionReference(name);
}

void main() {
  test('Razorpay success path: creates order, clears cart, creates booking', () async {
    final orderRepo = FakeOrderRepo();
    final razor = FakeRazorpay(const PaymentSuccess(paymentId: 'pay_1', orderId: 'ord_1'));
    final cod = FakeCod(const PaymentSuccess(paymentId: 'COD', orderId: null));
    final cart = FakeCartRepo();
    final booking = FakeBookingRepo();
    final fakeFs = FakeFirestoreInstance();

    final bloc = CheckoutBloc(
      orderRepo: orderRepo,
      razorpayRepo: razor,
      codRepo: cod,
      cartRepo: cart,
      // bookingRepo: booking,
      getCurrentUserId: () async => 'uid_test',
      firestore: fakeFs,
    );

    final req = PaymentRequest(totalAmount: 100.0, userEmail: 'a@b.com', userPhone: '999', userName: 'Test', userAddress: 'Addr', items: []);
    bloc.add(CheckoutSubmitted(request: req, paymentMethod: 'razorpay'));

    final state = await bloc.stream.firstWhere((s) => !s.isInProgress);
    expect(state.successMessage, isNotNull);
    expect(orderRepo.uploaded, isTrue);
    expect(cart.cleared, isTrue);
    expect(booking.created, isTrue);
  });

  test('Razorpay failure path: does not create order', () async {
    final orderRepo = FakeOrderRepo();
    final razor = FakeRazorpay(const PaymentFailure(message: 'failed'));
    final cod = FakeCod(const PaymentSuccess(paymentId: 'COD', orderId: null));
    final cart = FakeCartRepo();
    final booking = FakeBookingRepo();
    final fakeFs = FakeFirestoreInstance();

    final bloc = CheckoutBloc(
      orderRepo: orderRepo,
      razorpayRepo: razor,
      codRepo: cod,
      cartRepo: cart,
      // bookingRepo: booking,
      getCurrentUserId: () async => 'uid_test',
      firestore: fakeFs,
    );

    final req = PaymentRequest(totalAmount: 80.0, userEmail: 'x@y.com', userPhone: '888', userName: 'User', userAddress: 'Addr', items: []);
    bloc.add(CheckoutSubmitted(request: req, paymentMethod: 'razorpay'));
    final state = await bloc.stream.firstWhere((s) => !s.isInProgress);
    expect(state.errorMessage, isNotNull);
    expect(orderRepo.uploaded, isFalse);
    expect(cart.cleared, isFalse);
    expect(booking.created, isFalse);
  });

  test('COD path: creates order and clears cart', () async {
    final orderRepo = FakeOrderRepo();
    final razor = FakeRazorpay(const PaymentFailure(message: 'not used'));
    final cod = FakeCod(const PaymentSuccess(paymentId: 'COD', orderId: null));
    final cart = FakeCartRepo();
    final booking = FakeBookingRepo();
    final fakeFs = FakeFirestoreInstance();

    final bloc = CheckoutBloc(
      orderRepo: orderRepo,
      razorpayRepo: razor,
      codRepo: cod,
      cartRepo: cart,
      // bookingRepo: booking,
      getCurrentUserId: () async => 'uid_test',
      firestore: fakeFs,
    );

    final req = PaymentRequest(totalAmount: 70.0, userEmail: 'u@v.com', userPhone: '777', userName: 'V', userAddress: 'Addr', items: []);
    bloc.add(CheckoutSubmitted(request: req, paymentMethod: 'cod'));

    final state = await bloc.stream.firstWhere((s) => !s.isInProgress);
    expect(state.successMessage, isNotNull);
    expect(orderRepo.uploaded, isTrue);
    expect(cart.cleared, isTrue);
    expect(booking.created, isTrue);
  });
}

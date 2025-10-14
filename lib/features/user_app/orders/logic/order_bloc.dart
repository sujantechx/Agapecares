import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/order_model.dart';
import 'order_event.dart';
import 'order_state.dart';
import '../data/repositories/order_repository.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _orderRepository;

  OrderBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(OrderLoading()) {
    on<LoadOrders>(_onLoadOrders);
    on<AddOrder>(_onAddOrder);
  }

  void _onLoadOrders(LoadOrders event, Emitter<OrderState> emit) async {
    try {
      final orders = await _orderRepository.fetchOrdersForUser(event.userId);
      emit(OrderLoaded(orders));
    } catch (_) {
      emit(OrderError());
    }
  }

  void _onAddOrder(AddOrder event, Emitter<OrderState> emit) async {
    if (state is OrderLoaded) {
      final List<OrderModel> updatedOrders =
          List.from((state as OrderLoaded).orders)..add(event.order);
      // Ideally, we'd get the new order back from the repository
      emit(OrderLoaded(updatedOrders));
      await _orderRepository.createOrder(event.order);
    }
  }
}


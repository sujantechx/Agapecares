import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_order_event.dart';
import 'admin_order_state.dart';
import '../../domain/repositories/order_repository.dart';

class AdminOrderBloc extends Bloc<AdminOrderEvent, AdminOrderState> {
  final OrderRepository repo;
  AdminOrderBloc({required this.repo}) : super(AdminOrderInitial()) {
    on<LoadOrders>((event, emit) async {
      emit(AdminOrderLoading());
      try {
        final orders = await repo.getAllOrders(filters: event.filters);
        emit(AdminOrderLoaded(orders));
      } catch (e) {
        emit(AdminOrderError(e.toString()));
      }
    });

    on<UpdateOrderStatusEvent>((event, emit) async {
      try {
        await repo.updateOrderStatus(orderId: event.orderId, status: event.status);
        add(LoadOrders());
      } catch (e) {
        emit(AdminOrderError(e.toString()));
      }
    });

    on<AssignWorkerEvent>((event, emit) async {
      try {
        await repo.assignWorker(orderId: event.orderId, workerId: event.workerId, workerName: event.workerName);
        add(LoadOrders());
      } catch (e) {
        emit(AdminOrderError(e.toString()));
      }
    });

    on<DeleteOrderEvent>((event, emit) async {
      try {
        await repo.deleteOrder(event.orderId);
        add(LoadOrders());
      } catch (e) {
        emit(AdminOrderError(e.toString()));
      }
    });
  }
}

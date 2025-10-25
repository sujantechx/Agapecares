// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\logic\blocs\worker_tasks_bloc.dart

import 'dart:async';

import 'package:bloc/bloc.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'worker_tasks_event.dart';
import 'worker_tasks_state.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;

// Private event used only inside this library to pass stream updates into the Bloc
class _WorkerOrdersUpdated extends WorkerTasksEvent {
  final List<OrderModel> orders;
  const _WorkerOrdersUpdated(this.orders);
  @override
  List<Object?> get props => [orders];
}

class WorkerTasksBloc extends Bloc<WorkerTasksEvent, WorkerTasksState> {
  final user_orders_repo.OrderRepository orderRepository;
  final SessionService sessionService;

  // Subscription to the repository's real-time stream
  StreamSubscription<List<OrderModel>>? _ordersSub;

  WorkerTasksBloc({required this.orderRepository, required this.sessionService}) : super(WorkerTasksInitial()) {
    on<LoadWorkerOrders>(_onLoad);
    on<RefreshWorkerOrders>(_onRefresh);
    on<UpdateOrderStatus>(_onUpdateStatus);
    // Internal event to receive stream updates
    on<_WorkerOrdersUpdated>(_onStreamUpdated);
  }

  Future<void> _onLoad(LoadWorkerOrders event, Emitter<WorkerTasksState> emit) async {
    emit(WorkerTasksLoading());
    try {
      final user = sessionService.getUser();
      if (user == null) {
        emit(const WorkerTasksFailure('No session available.'));
        return;
      }
      final workerId = user.uid;

      // Cancel any previous subscription before creating a new one
      await _ordersSub?.cancel();

      // Subscribe to the repository stream which emits lists of orders in real-time
      _ordersSub = orderRepository.streamOrdersForWorker(workerId).listen((orders) {
        // Push the list into the bloc through a private event so that all
        // state transitions happen within the Bloc's event handlers.
        add(_WorkerOrdersUpdated(orders));
      }, onError: (err, stack) {
        addError(err, stack);
      });

      // If forceRefresh requested, optionally trigger repository push-based refresh
      // (some implementations of the repository may ignore this). We'll keep this
      // simple: the stream will provide current items shortly after subscription.
    } catch (e) {
      emit(WorkerTasksFailure(e.toString()));
    }
  }

  Future<void> _onRefresh(RefreshWorkerOrders event, Emitter<WorkerTasksState> emit) async {
    // Re-subscribe to the stream to attempt a fresh snapshot (cancel + load)
    add(const LoadWorkerOrders(forceRefresh: true));
  }

  Future<void> _onUpdateStatus(UpdateOrderStatus event, Emitter<WorkerTasksState> emit) async {
    emit(WorkerTasksUpdating());
    try {
      final updated = event.order.copyWith(orderStatus: event.newStatus);
      await orderRepository.updateOrder(updated);
      emit(WorkerTasksUpdateSuccess());
      // No need to manually reload — stream will emit the updated list when backend writes are committed.
    } catch (e) {
      emit(WorkerTasksUpdateFailure(e.toString()));
    }
  }

  Future<void> _onStreamUpdated(_WorkerOrdersUpdated event, Emitter<WorkerTasksState> emit) async {
    final orders = event.orders;
    if (orders.isEmpty) {
      emit(WorkerTasksEmpty());
      return;
    }

    // Partition orders into upcoming, today, past
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final upcoming = <OrderModel>[];
    final today = <OrderModel>[];
    final past = <OrderModel>[];

    for (final o in orders) {
      DateTime? scheduled;
      try {
        scheduled = o.scheduledAt.toDate();
      } catch (_) {
        // If scheduledAt isn't a Timestamp-compatible object, default to now
        scheduled = now;
      }

      if (scheduled.isBefore(todayStart)) {
        past.add(o);
      } else if (scheduled.isAfter(todayEnd)) {
        upcoming.add(o);
      } else {
        today.add(o);
      }
    }

    emit(WorkerTasksLoaded(upcoming: upcoming, today: today, past: past));
  }

  @override
  Future<void> close() async {
    await _ordersSub?.cancel();
    return super.close();
  }
}

import 'package:equatable/equatable.dart';
import '../../../../../shared/models/order_model.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object> get props => [];
}

class LoadOrders extends OrderEvent {
  final String userId;

  const LoadOrders(this.userId);

  @override
  List<Object> get props => [userId];
}

class AddOrder extends OrderEvent {
  final OrderModel order;

  const AddOrder(this.order);

  @override
  List<Object> get props => [order];
}


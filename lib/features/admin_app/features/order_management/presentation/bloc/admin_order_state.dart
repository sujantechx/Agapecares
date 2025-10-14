import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/order_model.dart';

abstract class AdminOrderState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminOrderInitial extends AdminOrderState {}
class AdminOrderLoading extends AdminOrderState {}
class AdminOrderLoaded extends AdminOrderState {
  final List<OrderModel> orders;
  AdminOrderLoaded(this.orders);
  @override
  List<Object?> get props => [orders];
}
class AdminOrderError extends AdminOrderState {
  final String message;
  AdminOrderError(this.message);
  @override
  List<Object?> get props => [message];
}


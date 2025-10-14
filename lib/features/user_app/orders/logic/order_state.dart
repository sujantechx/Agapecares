import 'package:equatable/equatable.dart';
import '../../../../../shared/models/order_model.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object> get props => [];
}

class OrderLoading extends OrderState {}

class OrderLoaded extends OrderState {
  final List<OrderModel> orders;

  const OrderLoaded([this.orders = const []]);

  @override
  List<Object> get props => [orders];
}

class OrderError extends OrderState {}


import 'package:equatable/equatable.dart';
import '../../../../../core/models/cart_item_model.dart';


abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object> get props => [];
}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  final List<CartItemModel> items;

  const CartLoaded([this.items = const []]);

  @override
  List<Object> get props => [items];
}

class CartError extends CartState {}


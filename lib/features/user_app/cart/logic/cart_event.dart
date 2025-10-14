import 'package:equatable/equatable.dart';
import '../../../../../shared/models/cart_item_model.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object> get props => [];
}

class LoadCart extends CartEvent {
  final String userId;

  const LoadCart(this.userId);

  @override
  List<Object> get props => [userId];
}

class AddItem extends CartEvent {
  final CartItemModel item;

  const AddItem(this.item);

  @override
  List<Object> get props => [item];
}

class RemoveItem extends CartEvent {
  final String itemId;

  const RemoveItem(this.itemId);

  @override
  List<Object> get props => [itemId];
}


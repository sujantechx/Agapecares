import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/cart_item_model.dart';


abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object> get props => [];
}

class LoadCart extends CartEvent {
  const LoadCart();

  @override
  List<Object> get props => [];

  get userId => null;
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

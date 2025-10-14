import 'package:flutter_bloc/flutter_bloc.dart';
import 'cart_event.dart';
import 'cart_state.dart';
import '../data/repositories/cart_repository.dart';
import '../../../../../shared/models/cart_item_model.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRepository _cartRepository;
  final String userId;

  CartBloc({required CartRepository cartRepository, required this.userId})
      : _cartRepository = cartRepository,
        super(CartLoading()) {
    on<LoadCart>(_onLoadCart);
    on<AddItem>(_onAddItem);
    on<RemoveItem>(_onRemoveItem);
  }

  void _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    try {
      final items = await _cartRepository.getCartItems(event.userId);
      emit(CartLoaded(items));
    } catch (_) {
      emit(CartError());
    }
  }

  void _onAddItem(AddItem event, Emitter<CartState> emit) async {
    if (state is CartLoaded) {
      final List<CartItemModel> updatedItems =
          List.from((state as CartLoaded).items)..add(event.item);
      await _cartRepository.addCartItem(userId, event.item);
      emit(CartLoaded(updatedItems));
    }
  }

  void _onRemoveItem(RemoveItem event, Emitter<CartState> emit) async {
    if (state is CartLoaded) {
      final List<CartItemModel> updatedItems = (state as CartLoaded)
          .items
          .where((item) => item.id != event.itemId)
          .toList();
      await _cartRepository.removeCartItem(userId, event.itemId);
      emit(CartLoaded(updatedItems));
    }
  }
}


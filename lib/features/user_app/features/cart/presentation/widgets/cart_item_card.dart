import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_bloc.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_event.dart';
import 'package:agapecares/core/models/cart_item_model.dart';

class CartItemCard extends StatelessWidget {
  final CartItemModel item;
  const CartItemCard({super.key, required this.item});

  String get _compositeId => '${item.serviceId}_${item.optionName}';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Service Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.serviceName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item.optionName,
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Price (unit price x quantity shown as unit price here)
                Text(
                  '₹ ${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity Controls
                _buildQuantityControls(context),
                // Remove Button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                  onPressed: () {
                    context.read<CartBloc>().add(CartItemRemoved(_compositeId));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: item.quantity > 1
                ? () => context
                .read<CartBloc>()
                .add(CartItemQuantityDecreased(_compositeId))
                : null, // Disable if quantity is 1
            splashRadius: 20,
          ),
          Text('${item.quantity}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.read<CartBloc>().add(CartItemQuantityIncreased(_compositeId));
            },
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
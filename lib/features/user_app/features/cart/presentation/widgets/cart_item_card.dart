import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/cart_bloc.dart';
import '../../bloc/cart_event.dart';
import '../../data/models/cart_item_model.dart';

class CartItemCard extends StatelessWidget {
  final CartItemModel item;
  const CartItemCard({super.key, required this.item});

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
                      Text(item.selectedOption.name,
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Price
                Text(
                  '₹ ${item.price.toStringAsFixed(2)}',
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
                    context.read<CartBloc>().add(CartItemRemoved(item.id));
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
                .add(CartItemQuantityDecreased(item.id))
                : null, // Disable if quantity is 1
            splashRadius: 20,
          ),
          Text('${item.quantity}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.read<CartBloc>().add(CartItemQuantityIncreased(item.id));
            },
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
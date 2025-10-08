import 'package:agapecares/features/user_app/cart/presentation/widgets/cart_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';


class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController couponController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your Cart is Empty', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return CartItemCard(item: item);
                  },
                ),
              ),
              _buildSummary(context, state, couponController),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(
      BuildContext context,
      CartState state,
      TextEditingController controller,
      ) {
    // 🎯 Listen for error messages from the BLoC state
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error!)));
      });
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 5)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coupon Section
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter Coupon (e.g. AGAPE10)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: state.appliedCoupon != null
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    context.read<CartBloc>().add(CartCouponApplied(controller.text));
                    FocusScope.of(context).unfocus();
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 🎯 New, Detailed Pricing Section
          _priceRow('Subtotal', '₹ ${state.subtotal.toStringAsFixed(2)}'),

          if (state.couponDiscount > 0 && state.appliedCoupon != null)
            _priceRow(
              'Coupon (${state.appliedCoupon!.code})',
              '- ₹ ${state.couponDiscount.toStringAsFixed(2)}',
              color: Colors.green,
            ),

          if (state.extraDiscount > 0 && state.extraOffer != null)
            _priceRow(
              'Extra Offer (${state.extraOffer!.description})',
              '- ₹ ${state.extraDiscount.toStringAsFixed(2)}',
              color: Colors.deepOrange,
            ),

          const Divider(height: 24),
          _priceRow('Total', '₹ ${state.total.toStringAsFixed(2)}', isTotal: true),
          const SizedBox(height: 16),
          // Buy Now Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checkout process started!')),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('Buy Now'),
            ),
          ),
        ],
      ),
    );
  }
// The _priceRow helper remains the same.

  Widget _priceRow(String title, String amount, {Color? color, bool isTotal = false}) {
    final style = TextStyle(
      fontSize: isTotal ? 20 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: style),
          Text(amount, style: style),
        ],
      ),
    );
  }
}
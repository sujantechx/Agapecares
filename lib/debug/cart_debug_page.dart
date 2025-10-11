import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agapecares/features/user_app/cart/data/models/cart_item_model.dart';
import 'package:agapecares/features/user_app/cart/data/repository/cart_repository.dart';
import 'package:agapecares/shared/models/service_list_model.dart';
import 'package:agapecares/features/user_app/data/fixed_data/all_services.dart';
import 'package:agapecares/shared/models/service_option_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CartDebugPage extends StatefulWidget {
  const CartDebugPage({super.key});

  @override
  State<CartDebugPage> createState() => _CartDebugPageState();
}

class _CartDebugPageState extends State<CartDebugPage> {
  List<CartItemModel> _items = [];
  bool _loading = false;

  Future<void> _reload(CartRepository repo) async {
    setState(() => _loading = true);
    final items = await repo.getCartItems();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addSample(CartRepository repo) async {
    setState(() => _loading = true);
    try {
      final service = await ServiceStore.instance.fetchById('1');
      if (service == null) throw Exception('Sample service not found');
      final ServiceOption option = service.options.first;
      final id = 'debug_${service.id}_${option.id}';
      final item = CartItemModel(
        id: id,
        service: service,
        selectedOption: option,
        quantity: 1,
      );
      await repo.addItemToCart(item);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added debug item')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    } finally {
      await _reload(repo);
    }
  }

  Future<void> _clear(CartRepository repo) async {
    setState(() => _loading = true);
    await repo.clearCart();
    await _reload(repo);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryProvider.of<CartRepository>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!kReleaseMode)
              Row(
                children: [
                  ElevatedButton(onPressed: () => _addSample(repo), child: const Text('Add Sample')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _reload(repo), child: const Text('Reload')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _clear(repo), child: const Text('Clear')),
                ],
              ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final it = _items[index];
                    return ListTile(
                      title: Text(it.service.name),
                      subtitle: Text('Option: ${it.selectedOption.name}  qty: ${it.quantity}'),
                      trailing: Text('₹ ${it.price.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Cart debug page removed - kept placeholder to avoid analyzer issues.
// This file intentionally left minimal. Use LocalDatabaseService logs to debug cart persistence.

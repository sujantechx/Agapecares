import 'package:flutter/material.dart';

class OrderDetailPage extends StatelessWidget {
  final String orderId;

  const OrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details'),
      ),
      body: Center(
        child: Text('Order Details for $orderId'),
      ),
    );
  }
}


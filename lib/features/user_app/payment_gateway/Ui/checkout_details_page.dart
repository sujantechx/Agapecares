/*
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';


import 'package:agapecares/routes/app_routes.dart';

import '../../../../shared/models/order_model.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_event.dart';

// 🎯 Centralized constants for easier updates
const String _backendUrl = 'http://localhost:8080/create-order';
const String _razorpayKeyId = 'YOUR_RAZORPAY_TEST_KEY_ID'; // Replace with your public Test Key ID

class CheckoutDetailsPage extends StatefulWidget {
  final double totalAmount;
  const CheckoutDetailsPage({super.key, required this.totalAmount});

  @override
  State<CheckoutDetailsPage> createState() => _CheckoutDetailsPageState();
}

class _CheckoutDetailsPageState extends State<CheckoutDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // --- LOGIC FOR CREATING AND SAVING THE ORDER ---
  Future<void> _createAndSaveOrder({required String paymentMethod, String? paymentId}) async {
    // This function now uses the navigator from the context before the async gap.
    final navigator = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cartBloc = context.read<CartBloc>();

    setState(() => _isLoading = true);

    final cartState = cartBloc.state;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please log in to place an order.')));
      setState(() => _isLoading = false);
      return;
    }

    final newOrder = OrderModel(
      userId: currentUser.uid,
      items: cartState.items,
      subtotal: cartState.subtotal,
      discount: cartState.couponDiscount + cartState.extraDiscount,
      total: cartState.total,
      paymentMethod: paymentMethod,
      paymentId: paymentId,
      userName: _nameController.text,
      userEmail: _emailController.text,
      userPhone: _phoneController.text,
      userAddress: _addressController.text,
      createdAt: Timestamp.now(),
    );

    try {
      await FirebaseFirestore.instance.collection('orders').add(newOrder.toJson());
      cartBloc.add(CartStarted()); // Clear the cart after successful order
      navigator.go(AppRoutes.orderSuccess, extra: {
        'message': 'Order placed successfully ($paymentMethod)!',
        'paymentId': paymentId ?? 'N/A',
      });
    } catch (e) {
      navigator.go(AppRoutes.orderFailure, extra: "Failed to save your order.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- RAZORPAY PAYMENT HANDLING ---
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (response.paymentId != null) {
      _createAndSaveOrder(paymentMethod: 'Razorpay', paymentId: response.paymentId);
    } else {
      GoRouter.of(context).go(AppRoutes.orderFailure, extra: "Payment ID was not received.");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    GoRouter.of(context).go(AppRoutes.orderFailure, extra: response.message ?? 'Unknown payment error.');
  }

  Future<void> _processRazorpayPayment() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final amountInPaise = (widget.totalAmount * 100).toInt();
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amountInPaise}),
      );

      if (response.statusCode != 200) {
        throw Exception('Server Error: Failed to create payment order.');
      }

      final orderData = jsonDecode(response.body);
      final orderId = orderData['id'];

      final options = {
        'key': _razorpayKeyId,
        'amount': amountInPaise,
        'name': 'Agape Cares',
        'order_id': orderId,
        'description': 'Service Payment',
        'prefill': {'contact': _phoneController.text, 'email': _emailController.text}
      };

      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- CASH ON DELIVERY HANDLING ---
  void _processCodOrder() {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    _createAndSaveOrder(paymentMethod: 'Cash on Delivery');
  }

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ... Your existing UI form fields ...
              Text('Total Amount: ₹ ${widget.totalAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Please enter your name' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Please enter your email' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Please enter your phone number' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()), maxLines: 3, validator: (v) => v!.isEmpty ? 'Please enter your address' : null),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _processRazorpayPayment,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                child: const Text('Pay with Razorpay'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : _processCodOrder,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                child: const Text('Cash on Delivery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/

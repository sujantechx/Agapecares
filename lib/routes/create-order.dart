// ignore_for_file: depend_on_referenced_packages, uri_does_not_exist, non_type_as_type_argument, undefined_class, undefined_identifier, undefined_function, file_names
// filepath: c:\FlutterDev\project\agapecares\lib\routes\create-order.dart
// File: server/routes/create-order.dart
import 'dart:convert';
import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
/// POST /create-order
/// Body: { "amount": 100 } // in paise
/// Make sure RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are set in environment.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>?;
  final amount = (body?['amount'] is int) ? body!['amount'] as int : null;
  if (amount == null || amount <= 0) {
    return Response.json(statusCode: HttpStatus.badRequest, body: {'error': 'Invalid amount'});
  }

  final keyId = Platform.environment['RAZORPAY_KEY_ID'];
  final keySecret = Platform.environment['RAZORPAY_KEY_SECRET'];
  if (keyId == null || keySecret == null) {
    return Response.json(statusCode: HttpStatus.internalServerError, body: {'error': 'Razorpay creds missing'});
  }

  final uri = Uri.parse('https://api.razorpay.com/v1/orders');
  final credentials = base64Encode(utf8.encode('$keyId:$keySecret'));
  final receipt = 'rcpt_${DateTime.now().millisecondsSinceEpoch}';
  try {
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'amount': amount,
        'currency': 'INR',
        'receipt': receipt,
        'payment_capture': 1,
      }),
    );
    return Response(
      statusCode: resp.statusCode,
      body: resp.body,
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.json(statusCode: HttpStatus.internalServerError, body: {'error': e.toString()});
  }
}

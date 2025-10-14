import 'package:flutter/material.dart';

class SplasseScreen extends StatelessWidget {
  const SplasseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: Center(
          child: Container(
        width: 200,
        height: 200,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/logos/ap_logo.png'),
            fit: BoxFit.cover,
          ),),
    )),
    );
  }
}

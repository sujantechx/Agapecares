// lib/shared/widgets/common_button.dart

import 'package:flutter/material.dart';

class CommonButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;

  const CommonButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.0,
          ),
        )
            : Text(text),
      ),
    );
  }
}
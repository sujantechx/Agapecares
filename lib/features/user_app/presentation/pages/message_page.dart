// lib/features/user_app/presentation/pages/message_page.dart

import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Messages Yet',
              style: TextStyle(fontSize: 22, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
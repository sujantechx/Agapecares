import 'package:flutter/material.dart';

class OurBlogPage extends StatelessWidget {
  const OurBlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Our Blog')),
      body: const Center(child: Text('List of blog posts')),
    );
  }
}
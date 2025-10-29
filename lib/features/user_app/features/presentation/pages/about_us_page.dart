import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Using theme styles for consistent typography
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
      ),
      // Use a ListView to ensure content is scrollable
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Header/Logo Section
          Icon(
            Icons.business, // Placeholder icon
            size: 100,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to AgapeCares Services',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We are dedicated to providing the best home services in the city, connecting you with trusted, skilled, and verified professionals right at your doorstep.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const Divider(height: 32),

          // 2. Our Mission Section
          _buildSectionHeader('Our Mission', textTheme),
          _buildParagraph(
            'Our mission is simple: to make home life easier and more convenient. We aim to solve all your home-related problems with a single tap, offering a wide range of services from cleaning and repairs to pest control and beauty, all delivered with the highest standards of quality and safety.',
            textTheme,
          ),
          const SizedBox(height: 24),

          // 3. Why Choose Us? Section
          _buildSectionHeader('Why Choose Us?', textTheme),
          const SizedBox(height: 8),
          _buildFeatureTile(
            icon: Icons.verified_user_outlined,
            title: 'Verified Professionals',
            subtitle: 'Every professional on our platform is background-checked and trained.',
          ),
          _buildFeatureTile(
            icon: Icons.price_check_outlined,
            title: 'Upfront Pricing',
            subtitle: 'No hidden fees. You see the price before you book the service.',
          ),
          _buildFeatureTile(
            icon: Icons.support_agent_outlined,
            title: 'Dedicated Support',
            subtitle: 'Our customer support team is always ready to help you with any query.',
          ),
          _buildFeatureTile(
            icon: Icons.shield_outlined,
            title: 'Service Guarantee',
            subtitle: 'We offer a satisfaction guarantee on all our services.',
          ),
          const SizedBox(height: 24),

          // 4. Our Team Section
          _buildSectionHeader('Our Team', textTheme),
          _buildParagraph(
            'Nakoda Urban Services was founded by a passionate team of entrepreneurs who were tired of the hassle of finding reliable home service providers. We are a blend of tech experts, operations managers, and customer service enthusiasts working tirelessly to build a service you can trust.',
            textTheme,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Helper widget for building section headers
  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// Helper widget for building paragraph text
  Widget _buildParagraph(String text, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: textTheme.bodyLarge?.copyWith(height: 1.5, fontSize: 16),
      ),
    );
  }

  /// Helper widget for feature list items
  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }
}
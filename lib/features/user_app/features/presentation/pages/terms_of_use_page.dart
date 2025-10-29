import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Using theme styles for consistent typography
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      // Use a ListView for scrollable text content
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Welcome to Our Cleaning Service',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildParagraph(
            'These terms and conditions outline the rules and regulations for the use of our cleaning services. By booking a service with us, you ("the User," "you") accept these terms and conditions in full. Do not continue to use our services if you do not accept all of the terms stated on this page.',
            textTheme,
          ),
          const SizedBox(height: 16),

          // --- Section 1: Services ---
          _buildSectionHeader('1. Scope of Service', textTheme),
          _buildParagraph(
            'We agree to provide residential and/or commercial cleaning services as detailed and agreed upon at the time of booking. Our services are subject to the availability of our professional cleaning staff. We reserve the right to decline any booking request for any reason.',
            textTheme,
          ),
          const SizedBox(height: 16),

          // --- Section 2: User Obligations ---
          _buildSectionHeader('2. Your Obligations', textTheme),
          _buildParagraph(
            'As the customer, you agree to the following: (a) Provide our staff with safe and unobstructed access to your property at the scheduled time. (b) Ensure a safe working environment, free from hazards, and secure any pets to prevent interference. (c) Provide access to necessary utilities, including hot water and electricity, for the duration of the service.',
            textTheme,
          ),
          const SizedBox(height: 16),

          // --- Section 3: Payment and Cancellations ---
          _buildSectionHeader('3. Payment and Cancellations', textTheme),
          _buildParagraph(
            'Payment for services is due at the time of booking through our platform unless otherwise agreed. Prices are based on the information provided by you at booking; additional charges may apply if the scope of work exceeds the original quote (e.g., excessive soiling, additional rooms).',
            textTheme,
          ),
          _buildParagraph(
            'Cancellations must be made at least 24 hours prior to the scheduled service time to be eligible for a full refund. Cancellations made with less than 24 hours\' notice, or if our staff is denied access upon arrival, may be subject to a cancellation fee equivalent to 50% of the service cost.',
            textTheme,
          ),
          const SizedBox(height: 16),

          // --- Section 4: Liability and Damages ---
          _buildSectionHeader('4. Liability and Damages', textTheme),
          _buildParagraph(
            'Our cleaning staff exercises reasonable care with your property. We are insured for accidental damages. However, we are not liable for pre-existing damage, or damage resulting from faulty items or improper installation (e.g., loose fixtures, improperly hung pictures).',
            textTheme,
          ),
          _buildParagraph(
            'You must report any accidental damage caused by our staff within 24 hours of the service completion. Our liability shall be limited to repairing the damaged item or providing a replacement, at our sole discretion.',
            textTheme,
          ),
          const SizedBox(height: 16),

          // --- Section 5: Satisfaction Guarantee ---
          _buildSectionHeader('5. Satisfaction Guarantee', textTheme),
          _buildParagraph(
            'We strive for 100% satisfaction. If you are not satisfied with any aspect of our service, please report the issue within 24 hours of the cleaning. We will arrange to re-clean the specific area(s) at no additional cost to you.',
            textTheme,
          ),
          const SizedBox(height: 16),

          // --- Section 6: Changes to Terms ---
          _buildSectionHeader('6. Changes to Terms', textTheme),
          _buildParagraph(
            'We reserve the right to modify these terms at any time. Any changes will be effective immediately upon posting to our platform. Your continued use of our service after such changes constitutes your acceptance of the new terms.',
            textTheme,
          ),
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
        // Using a slightly taller line height makes paragraphs easier to read
        style: textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }
}
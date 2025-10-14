import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';



class LocationSearchBar extends StatelessWidget {
  const LocationSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location display
          InkWell(
            onTap: () {
              // Handle location change
            },
            child: const Row(
              children: [
                Icon(Icons.location_on,
              ),
                SizedBox(width: 8),
                Text(
                  'Bhubaneswar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.arrow_drop_down,
                    color: AppTheme.subtitleColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Search bar and button
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'What are you looking for?',
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('SEARCH'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
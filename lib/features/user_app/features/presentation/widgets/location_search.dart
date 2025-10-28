import 'package:flutter/material.dart';

// Assuming AppTheme is defined elsewhere, like this:
// import '../../../../../app/theme/app_theme.dart';
class AppTheme {
  static Color subtitleColor = Colors.grey[600]!;
}
// ---

class Location {
  final String name;
  final int availableServices;

  const Location({required this.name, required this.availableServices});
}

class LocationSearchBar extends StatefulWidget {
  const LocationSearchBar({
    super.key,
    this.onLocationSelected,
    this.initialLocation,
  });

  // Updated to allow sending null when "Select Location" is tapped
  final ValueChanged<Location?>? onLocationSelected;
  final Location? initialLocation;

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  bool _showLocations = false;
  late Location? _selectedLocation;

  final List<Location> _locations = const [
    Location(name: 'Berhampur', availableServices: 3),
    Location(name: 'Bargarh', availableServices: 3),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  void _toggleLocations() {
    setState(() {
      _showLocations = !_showLocations;
    });
  }

  // Updated to accept a nullable Location
  void _selectLocation(Location? location) {
    setState(() {
      _selectedLocation = location;
      _showLocations = false;
    });
    // This will now call the callback with the selected location OR with null
    widget.onLocationSelected?.call(location);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header showing current selection
          InkWell(
            onTap: _toggleLocations,
            borderRadius: BorderRadius.circular(8.0), // Added for better tap feedback
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0), // Added padding
              child: Row(
                children: [
                  const Icon(Icons.location_on),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLocation?.name ?? 'Select Available Location',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        // Show available services OR a prompt to select
                        if (_selectedLocation != null)
                          Text(
                            '${_selectedLocation!} available services',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleColor,
                            ),
                          )
                        else
                        // New: Added a prompt when no location is selected
                          Text(
                            'Tap to see all locations',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _showLocations
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: AppTheme.subtitleColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Animated visibility of locations list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Card(
              margin: EdgeInsets.zero, // Removed default card margin
              child: Column(
                children: [
                  // --- NEW: Added "Select Location" (clear) option ---
                  ListTile(
                    leading: const Icon(Icons.location_off_outlined),
                    title: const Text('Select Location'),
                    subtitle: const Text('Clear current selection'),
                    trailing: _selectedLocation == null
                        ? const Icon(Icons.check, color: Colors.green)
                        : null, // Show check if this is the active state
                    onTap: () => _selectLocation(null), // Pass null to clear
                  ),
                  // --- End of new option ---

                  // Use a spread operator (...) to add the list of locations
                  ..._locations.map((loc) {
                    return Column(
                      children: [
                        const Divider(height: 1), // Divider at the top of each item
                        ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(loc.name),
                          subtitle: Text(
                              'Available services'),
                          trailing: _selectedLocation?.name == loc.name
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(Icons.chevron_right),
                          onTap: () => _selectLocation(loc),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            crossFadeState: _showLocations
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/models/service_option_model.dart';



class ServiceOptionsWidget extends StatefulWidget {
  final List<ServiceOption> options;
  // This callback function will notify the parent page of the selection.
  final Function(ServiceOption selectedOption) onOptionSelected;

  const ServiceOptionsWidget({
    super.key,
    required this.options,
    required this.onOptionSelected,
  });

  @override
  State<ServiceOptionsWidget> createState() => _ServiceOptionsWidgetState();
}

class _ServiceOptionsWidgetState extends State<ServiceOptionsWidget> {
  // The state will hold the currently selected option.
  // We initialize it with the first option in the list.
  late ServiceOption _selectedOption;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.options.first;
  }

  @override
  Widget build(BuildContext context) {
    // ExpansionTile is a built-in Flutter widget that creates a collapsible tile.
    return ExpansionTile(
      // The title shows the currently selected option.
      title: Text(
        _selectedOption.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        'Tap to see more options',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      // The children are the list of all available options.
      children: widget.options.map((option) {
        // RadioListTile is perfect for showing a list of exclusive choices.
        return RadioListTile<ServiceOption>(
          title: Text(option.name),
          secondary: Text(
            '₹ ${option.price}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          value: option,
          groupValue: _selectedOption,
          onChanged: (ServiceOption? value) {
            if (value != null) {
              setState(() {
                _selectedOption = value;
              });
              // When the selection changes, call the callback to notify the parent.
              widget.onOptionSelected(value);
            }
          },
          activeColor: AppTheme.primaryColor,
        );
      }).toList(),
    );
  }
}
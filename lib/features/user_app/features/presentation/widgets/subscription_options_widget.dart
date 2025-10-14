// lib/features/services/presentation/widgets/subscription_options_widget.dart

import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/models/subscription_plan_model.dart';


class SubscriptionOptionsWidget extends StatefulWidget {
  /// The list of subscription plans to display.
  final List<SubscriptionPlan> plans;

  /// A callback function that is triggered when the user selects a plan.
  /// It returns the selected [SubscriptionPlan], or `null` if "One-Time Purchase" is selected.
  final Function(SubscriptionPlan? selectedPlan) onPlanSelected;

  const SubscriptionOptionsWidget({
    super.key,
    required this.plans,
    required this.onPlanSelected,
  });

  @override
  State<SubscriptionOptionsWidget> createState() =>
      _SubscriptionOptionsWidgetState();
}

class _SubscriptionOptionsWidgetState extends State<SubscriptionOptionsWidget> {
  // This state variable holds the currently selected plan.
  // It is nullable (`?`) because `null` represents the "One-Time Purchase" option.
  SubscriptionPlan? _selectedPlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Subscription:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Wrap is used to allow the chips to flow to the next line on smaller screens.
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            // 1. The Default "One-Time Purchase" Chip
            ChoiceChip(
              label: const Text('One-Time Purchase'),
              // This chip is selected only when no subscription plan is chosen (_selectedPlan is null).
              selected: _selectedPlan == null,
              onSelected: (isSelected) {
                if (isSelected) {
                  setState(() {
                    _selectedPlan = null;
                  });
                  // Notify the parent page that no subscription is selected.
                  widget.onPlanSelected(null);
                }
              },
            ),

            // 2. Chips for each Subscription Plan
            ...widget.plans.map((plan) {
              return ChoiceChip(
                label: Text('${plan.name} (${plan.discount.round()}% off)'),
                // This chip is selected if its ID matches the selected plan's ID.
                selected: _selectedPlan?.id == plan.id,
                onSelected: (isSelected) {
                  if (isSelected) {
                    setState(() {
                      _selectedPlan = plan;
                    });
                    // Notify the parent page with the details of the chosen plan.
                    widget.onPlanSelected(plan);
                  }
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryColor,
              );
            }).toList(),
          ],
        ),
      ],
    );
  }
}
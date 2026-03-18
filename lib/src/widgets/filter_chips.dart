import 'package:flutter/material.dart';

class FilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final String selectedGmailLabel;
  final Function(String) onGmailLabelChanged;
  final bool gmailSignedIn;
  final bool gmailLoading;

  const FilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.selectedGmailLabel,
    required this.onGmailLabelChanged,
    this.gmailSignedIn = false,
    this.gmailLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filters: SMS, Gmail only
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'SMS', 'sms'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Gmail', 'gmail'),
              ],
            ),
          ),
          // Gmail: unread inbox only (no spam)
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => onFilterChanged(value),
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      side: BorderSide(
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
      ),
    );
  }

}

import 'package:flutter/material.dart';
import 'package:my_app/src/services/gmail_service.dart';

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
    final theme = Theme.of(context);
    final isGmailSelected = selectedFilter == 'gmail';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main filters: All, SMS, WhatsApp, Gmail
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'SMS', 'sms'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'WhatsApp', 'whatsapp'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Gmail', 'gmail'),
              ],
            ),
          ),
          // Gmail sub-filters: Inbox, Sent, Spam (only when Gmail selected and signed in)
          if (isGmailSelected && gmailSignedIn) ...[
            const SizedBox(height: 10),
            Text(
              'Gmail folders',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildGmailLabelChip(context, 'Inbox (unread)', GmailLabels.inbox, Icons.inbox),
                  const SizedBox(width: 8),
                  _buildGmailLabelChip(context, 'Spam', GmailLabels.spam, Icons.report),
                ],
              ),
            ),
          ],
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
          : Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildGmailLabelChip(BuildContext context, String label, String value, IconData icon) {
    final isSelected = selectedGmailLabel == value;
    final chipColor = value == GmailLabels.spam ? Colors.orange : null;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : (chipColor ?? Colors.grey[700])),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: gmailLoading ? null : (_) => onGmailLabelChanged(value),
      backgroundColor: isSelected
          ? (chipColor ?? Theme.of(context).colorScheme.primary)
          : (chipColor?.withValues(alpha: 0.15) ?? Colors.grey[100]),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (chipColor ?? Colors.black87),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      selectedColor: chipColor ?? Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
    );
  }
}

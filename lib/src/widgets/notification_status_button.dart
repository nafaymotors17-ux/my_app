import 'package:flutter/material.dart';

class NotificationStatusButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const NotificationStatusButton({
    super.key,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Tooltip(
          message: isEnabled
              ? 'Notification listener active'
              : 'Enable notification listener',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green[100]
                    : Colors.orange[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEnabled
                        ? Icons.check_circle
                        : Icons.notifications,
                    color: isEnabled
                        ? Colors.green
                        : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isEnabled ? 'Active' : 'Enable',
                    style: TextStyle(
                      color: isEnabled
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

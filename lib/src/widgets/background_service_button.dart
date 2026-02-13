import 'package:flutter/material.dart';

class BackgroundServiceButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onTap;

  const BackgroundServiceButton({
    super.key,
    required this.isRunning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Tooltip(
          message: isRunning
              ? 'Background SMS listener is running'
              : 'Start background SMS listener',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isRunning
                    ? Colors.blue[100]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRunning
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: isRunning
                        ? Colors.blue
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRunning ? 'Running' : 'Offline',
                    style: TextStyle(
                      color: isRunning
                          ? Colors.blue
                          : Colors.grey,
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

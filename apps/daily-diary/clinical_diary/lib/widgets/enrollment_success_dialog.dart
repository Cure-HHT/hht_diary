// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:flutter/material.dart';

/// Dialog widget that shows enrollment processing and success states
/// with an animated transition between them.
class EnrollmentSuccessDialog extends StatefulWidget {
  const EnrollmentSuccessDialog({super.key});

  @override
  State<EnrollmentSuccessDialog> createState() =>
      _EnrollmentSuccessDialogState();
}

class _EnrollmentSuccessDialogState extends State<EnrollmentSuccessDialog> {
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    // Transition to success state after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showSuccess = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showSuccess) ...[
              // Processing state
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Processing...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else ...[
              // Success state
              Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
              const SizedBox(height: 16),
              Text(
                'Success!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enrollment Confirmed',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

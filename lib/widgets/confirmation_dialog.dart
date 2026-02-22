import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String amount;
  final String message;

  const ConfirmationDialog({
    super.key,
    required this.amount,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('We detected a possible transaction:'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹$amount',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Message: "$message"'),
          const SizedBox(height: 16),
          const Text('Is this:'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChoice(context, 'Income', Colors.teal),
              _buildChoice(context, 'Expense', Colors.red),
              _buildChoice(context, 'Ignore', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoice(BuildContext context, String label, Color color) {
    return InkWell(
      onTap: () => Navigator.pop(context, label.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(label, style: TextStyle(color: color)),
      ),
    );
  }
}

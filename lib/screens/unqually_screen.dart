import 'package:flutter/material.dart';

class UnquallyScreen extends StatelessWidget {
  const UnquallyScreen({
    super.key,
    required this.memberNames,
  });

  final List<String> memberNames;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unequal split',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A4A8F),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This area is moved to a separate file so unequal split work can continue independently.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5A6E82),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: memberNames
                .map(
                  (name) => Chip(
                    label: Text(name),
                    backgroundColor: const Color(0xFFE9F4FF),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
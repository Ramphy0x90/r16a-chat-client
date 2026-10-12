import 'package:flutter/material.dart';

/// Desktop detail pane when nothing is selected yet ("Select a chat").
class EmptyPane extends StatelessWidget {
  final String message;

  const EmptyPane({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

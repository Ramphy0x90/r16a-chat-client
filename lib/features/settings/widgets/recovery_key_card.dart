import 'package:flutter/material.dart';

/// Shows a newly created recovery key once, until the user confirms they saved it.
class RecoveryKeyCard extends StatelessWidget {
  final String recoveryKey;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  const RecoveryKeyCard({
    super.key,
    required this.recoveryKey,
    required this.onCopy,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('Save your recovery key', style: textTheme.titleMedium),
            Text(
              'Store it somewhere safe, like a password manager. It\'s the '
              'only way to read your encrypted messages on a new login, and '
              'it won\'t be shown again.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                recoveryKey,
                style: textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(onPressed: onCopy, child: const Text('Copy')),
                ElevatedButton(
                  onPressed: onDone,
                  child: const Text('I\'ve saved it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

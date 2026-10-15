import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/zmey_progress.dart';
import 'package:r16a_chat_client/src/rust/api/recovery.dart';

/// Message backup status with the one action that fits it.
class RecoveryStatusCard extends StatelessWidget {
  /// Null while it's being checked.
  final RecoveryStatus? status;

  /// Setting up / replacing the key is running.
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onSetUp;
  final VoidCallback onEnterKey;
  final VoidCallback onResetKey;
  final VoidCallback onRetry;

  const RecoveryStatusCard({
    super.key,
    required this.status,
    required this.isWorking,
    required this.errorMessage,
    required this.onSetUp,
    required this.onEnterKey,
    required this.onResetKey,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = this.status;
    final errorMessage = this.errorMessage;

    if (status == null) {
      return const Center(child: ZmeyProgress());
    }

    final (title, text, action, onAction) = switch (status) {
      RecoveryStatus.enabled => (
        'Messages are backed up',
        'Keep your recovery key safe: you need it to read your encrypted '
            'messages after signing in again.',
        'Get a new recovery key',
        onResetKey,
      ),
      RecoveryStatus.disabled => (
        'Message backup is off',
        'If you log out or lose this device, your encrypted messages can\'t '
            'be read again. Set up a recovery key to back them up.',
        'Set up recovery',
        onSetUp,
      ),
      RecoveryStatus.incomplete => (
        'Recovery key needed',
        'Your messages are backed up, but this device needs your recovery '
            'key to read the older ones.',
        'Enter recovery key',
        onEnterKey,
      ),
      RecoveryStatus.unknown => (
        'Couldn\'t check the backup',
        'Check your connection and try again.',
        'Try again',
        onRetry,
      ),
    };
    // Resetting isn't the expected next step, keep it low-key.
    final isPrimaryAction = status != RecoveryStatus.enabled;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(title, style: textTheme.titleMedium),
            Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (errorMessage != null)
              Text(errorMessage, style: TextStyle(color: colors.error)),
            const SizedBox(height: 8),
            if (isWorking)
              const ZmeyProgress()
            else if (isPrimaryAction)
              ElevatedButton(onPressed: onAction, child: Text(action))
            else
              TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class LogoutTile extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const LogoutTile({super.key, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;

    return ListTile(
      title: Text('Log out', style: TextStyle(color: color)),
      trailing: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : null,
      onTap: isLoading ? null : onTap,
    );
  }
}

enum LogoutChoice { cancel, logout, setUpRecovery }

/// Asks before logging out. The text depends on whether the messages are
/// backed up (`isBackedUp`); if not, it also offers to set up recovery first.
Future<LogoutChoice> showLogoutConfirmDialog(
  BuildContext context, {
  required bool isBackedUp,
}) async {
  final choice = await showDialog<LogoutChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: Text(
        isBackedUp
            ? 'Your messages are backed up. You\'ll need your recovery key to '
                  'read encrypted messages after logging back in.'
            : 'Message backup isn\'t set up. Your encryption keys are deleted '
                  'from this device, so encrypted messages can\'t be read again '
                  'after logging back in.',
      ),
      actions: [
        if (!isBackedUp)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(LogoutChoice.setUpRecovery),
            child: const Text('Set up backup'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(LogoutChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(LogoutChoice.logout),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  return choice ?? LogoutChoice.cancel;
}

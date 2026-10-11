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

/// Resolves to true when the user confirms.
Future<bool> showLogoutConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'Your encryption keys are deleted from this device. '
        'Encrypted messages you received here can\'t be read again after logging back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

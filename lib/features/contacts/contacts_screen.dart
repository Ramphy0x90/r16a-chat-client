import 'package:flutter/material.dart';

/// Placeholder until the contacts list exists (people you share chats with,
/// plus contacts added by Matrix ID; needs Rust support).
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: Center(
        child: Text(
          'Contacts are coming soon',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

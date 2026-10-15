import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/features/auth/widgets/recovery_key_form.dart';
import 'package:r16a_chat_client/src/rust/api/recovery.dart';

/// "Enter your recovery key": unlocks the message backup on this device.
/// Shown right after logging in when a backup exists (`go`, done/skip lead to
/// the chats), and from Settings > Security (`push`, done pops back with true).
class RecoverScreen extends StatefulWidget {
  const RecoverScreen({super.key});

  @override
  State<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends State<RecoverScreen> {
  static const _maxContentWidth = 480.0;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Restore messages')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 24,
                children: [
                  Text(
                    'Enter your recovery key to read your encrypted messages '
                    'from before you signed in on this device.',
                    style: textTheme.bodyLarge,
                  ),
                  RecoveryKeyForm(
                    onSubmit: _handleRecover,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => _finish(false),
                    child: const Text('Not now'),
                  ),
                  Text(
                    'You can do this later in Settings > Security. Until then, '
                    'older encrypted messages show as "Can\'t decrypt".',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecover(String recoveryKey) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await recover(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        recoveryKey: recoveryKey,
      );
      if (mounted) _finish(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              "That didn't work. Check the key and try again. ($e)",
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _finish(bool recovered) {
    if (context.canPop()) {
      context.pop(recovered);
    } else {
      context.go(Routes.chats);
    }
  }
}

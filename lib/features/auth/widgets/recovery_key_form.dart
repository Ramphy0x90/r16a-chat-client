import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/zmey_progress.dart';

/// Recovery key input + submit. The key is a secret: no autocorrect or
/// suggestions, so the keyboard doesn't learn it.
class RecoveryKeyForm extends StatefulWidget {
  final void Function(String recoveryKey) onSubmit;
  final bool isLoading;
  final String? errorMessage;

  const RecoveryKeyForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<RecoveryKeyForm> createState() => _RecoveryKeyFormState();
}

class _RecoveryKeyFormState extends State<RecoveryKeyForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final errorMessage = widget.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextField(
          controller: _controller,
          enabled: !widget.isLoading,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'EsTj 3yST y93F …'),
          onSubmitted: (_) => _submit(),
        ),
        if (errorMessage != null)
          Text(errorMessage, style: TextStyle(color: colors.error)),
        ElevatedButton(
          onPressed: widget.isLoading ? null : _submit,
          child: widget.isLoading
              ? ZmeyProgress(color: colors.onPrimary)
              : const Text('Restore'),
        ),
      ],
    );
  }

  void _submit() {
    final key = _controller.text.trim();
    if (key.isNotEmpty) widget.onSubmit(key);
  }
}

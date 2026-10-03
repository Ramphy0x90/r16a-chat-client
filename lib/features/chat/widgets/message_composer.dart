import 'package:flutter/material.dart';

class MessageComposer extends StatefulWidget {
  /// Returns whether the message was sent, the input is only cleared on success.
  final Future<bool> Function(String text) onSend;
  final bool isSending;

  const MessageComposer({
    super.key,
    required this.onSend,
    required this.isSending,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;

    final sent = await widget.onSend(text);
    if (sent && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                cursorColor: colors.secondary,
                onSubmitted: (_) => _submit(),
                // Keep focus (and the mobile keyboard) after sending.
                onEditingComplete: () {},
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              onPressed: widget.isSending ? null : _submit,
              icon: widget.isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.secondary,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: colors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

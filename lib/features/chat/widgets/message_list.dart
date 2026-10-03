import 'package:flutter/material.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_bubble.dart';
import 'package:r16a_chat_client/src/rust/api/messages.dart';

class MessageList extends StatelessWidget {
  /// Oldest first.
  final List<MessageSummary> messages;

  const MessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Reversed so the list starts scrolled to the newest message at the bottom.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return MessageBubble(key: ValueKey(message.eventId), message: message);
      },
    );
  }
}

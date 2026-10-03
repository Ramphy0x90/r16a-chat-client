import 'dart:math';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/src/rust/api/messages.dart';

class MessageBubble extends StatelessWidget {
  final MessageSummary message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isOwn = message.isOwn;

    final sender = isOwn ? 'You' : _displaySender(message.sender);
    final time = _formatTime(message.timestampMs);

    return Semantics(
      container: true,
      label: '$sender, $time',
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            // Cap relative to width too, so own/other offset survives on phones.
            constraints: BoxConstraints(
              maxWidth: min(480, constraints.maxWidth * 0.8),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOwn ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  if (!isOwn)
                    Text(
                      sender,
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                  Text(message.body, style: TextStyle(color: colors.onSurface)),
                  Text(
                    time,
                    style: textTheme.labelSmall?.copyWith(
                      color: isOwn ? colors.onSurface : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "@alice:server" -> "alice"
  String _displaySender(String userId) {
    final localpart = userId.split(':').first;
    return localpart.startsWith('@') ? localpart.substring(1) : localpart;
  }

  String _formatTime(int timestampMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

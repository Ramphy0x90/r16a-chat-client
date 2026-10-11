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
                  _buildBody(colors, sender),
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

  Widget _buildBody(ColorScheme colors, String sender) {
    // Own bubbles sit on the accent color, where onSurfaceVariant is too faint.
    final mutedColor = message.isOwn
        ? colors.onSurface
        : colors.onSurfaceVariant;
    final placeholderStyle = TextStyle(
      color: mutedColor,
      fontStyle: FontStyle.italic,
    );

    return switch (message.kind) {
      MessageKind.text => Text(
        message.body,
        style: TextStyle(color: colors.onSurface),
      ),
      MessageKind.notice => Text(
        message.body,
        style: TextStyle(color: mutedColor),
      ),
      // Matrix convention: the action reads as a sentence with the sender.
      MessageKind.emote => Text(
        '${_displaySender(message.sender)} ${message.body}',
        style: TextStyle(color: colors.onSurface, fontStyle: FontStyle.italic),
      ),
      MessageKind.unableToDecrypt => Text(
        'Unable to decrypt this message',
        style: placeholderStyle,
      ),
      MessageKind.redacted => Text('Message deleted', style: placeholderStyle),
      MessageKind.unsupported => Text(
        message.body.isEmpty
            ? 'Unsupported message'
            : '${message.body} (not supported yet)',
        style: placeholderStyle,
      ),
    };
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

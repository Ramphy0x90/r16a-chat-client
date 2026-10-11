import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/features/chat/widgets/file_attachment.dart';
import 'package:r16a_chat_client/features/chat/widgets/image_attachment.dart';
import 'package:r16a_chat_client/src/rust/api/media.dart';
import 'package:r16a_chat_client/src/rust/api/messages.dart';

class MessageBubble extends StatelessWidget {
  final MessageSummary message;
  final Future<Uint8List> Function(MediaInfo media) loadPreview;
  final void Function(MediaInfo media) onOpenImage;
  final void Function(MediaInfo media) onSaveFile;

  /// Whether this message's file is being saved.
  final bool isSaving;

  const MessageBubble({
    super.key,
    required this.message,
    required this.loadPreview,
    required this.onOpenImage,
    required this.onSaveFile,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isOwn = message.isOwn;

    final sender = isOwn ? 'You' : _displaySender(message.sender);
    final time = _formatTime(message.timestampMs);
    final timeLabel = message.isEdited ? '$time · edited' : time;

    return Semantics(
      container: true,
      label: '$sender, $timeLabel',
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            // Cap relative to width too, so own/other offset survives on phones.
            constraints: BoxConstraints(
              maxWidth: min(480, constraints.maxWidth * 0.8),
            ),
            child: Column(
              crossAxisAlignment: isOwn
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                        timeLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: isOwn
                              ? colors.onPrimary.withValues(alpha: 0.7)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 3),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final reaction in message.reactions)
                          _ReactionChip(reaction: reaction),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors, String sender) {
    // Own bubbles sit on the accent fill (primary), so their text uses onPrimary.
    final textColor = message.isOwn ? colors.onPrimary : colors.onSurface;
    final mutedColor = message.isOwn
        ? colors.onPrimary.withValues(alpha: 0.7)
        : colors.onSurfaceVariant;
    final placeholderStyle = TextStyle(
      color: mutedColor,
      fontStyle: FontStyle.italic,
    );

    return switch (message.kind) {
      MessageKind.text => Text(
        message.body,
        style: TextStyle(color: textColor),
      ),
      MessageKind.notice => Text(
        message.body,
        style: TextStyle(color: mutedColor),
      ),
      // Matrix convention: the action reads as a sentence with the sender.
      MessageKind.emote => Text(
        '${_displaySender(message.sender)} ${message.body}',
        style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
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
      MessageKind.image ||
      MessageKind.file => _buildAttachment(colors, placeholderStyle),
    };
  }

  Widget _buildAttachment(ColorScheme colors, TextStyle placeholderStyle) {
    final media = message.media;
    // Rust always sets media for these kinds; guard anyway.
    if (media == null) {
      return Text('Unsupported message', style: placeholderStyle);
    }

    final attachment = message.kind == MessageKind.image
        ? ImageAttachment(
            media: media,
            loadPreview: loadPreview,
            onOpen: () => onOpenImage(media),
          )
        : FileAttachment(
            media: media,
            isSaving: isSaving,
            onSave: () => onSaveFile(media),
            isOwn: message.isOwn,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        attachment,
        if (message.body.isNotEmpty)
          Text(
            message.body,
            style: TextStyle(
              color: message.isOwn ? colors.onPrimary : colors.onSurface,
            ),
          ),
      ],
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

/// Display only for now, tapping doesn't add or remove a reaction.
class _ReactionChip extends StatelessWidget {
  final ReactionSummary reaction;

  const _ReactionChip({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label:
          '${reaction.key}, ${reaction.count}'
          '${reaction.reactedByMe ? ', including you' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          // secondary, not primary: maroon primary is near-invisible in dark mode.
          border: Border.all(
            color: reaction.reactedByMe ? colors.secondary : Colors.transparent,
          ),
        ),
        child: Text(
          '${reaction.key} ${reaction.count}',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }
}

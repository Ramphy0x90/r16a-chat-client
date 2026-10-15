import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_bubble.dart';
import 'package:r16a_chat_client/src/rust/api/media.dart';
import 'package:r16a_chat_client/src/rust/api/messages.dart';

class MessageList extends StatelessWidget {
  /// How close (in px) to the oldest loaded message scrolling triggers [onLoadOlder].
  static const _loadOlderThreshold = 400.0;

  /// Oldest first.
  final List<MessageSummary> messages;
  final bool isLoadingOlder;
  final bool hasReachedStart;

  /// Called when the user scrolls near the top. Can fire repeatedly while
  /// scrolling, the caller ignores calls while a load is running.
  final VoidCallback onLoadOlder;

  final Future<Uint8List> Function(MediaInfo media) loadPreview;
  final void Function(MediaInfo media) onOpenImage;
  final void Function(MediaInfo media) onSaveFile;

  /// Tapping one of our messages that failed to send.
  final void Function(MessageSummary message) onFailedTap;

  /// Handles of the files currently being saved.
  final Set<String> savingHandles;

  const MessageList({
    super.key,
    required this.messages,
    required this.isLoadingOlder,
    required this.hasReachedStart,
    required this.onLoadOlder,
    required this.loadPreview,
    required this.onOpenImage,
    required this.onSaveFile,
    required this.onFailedTap,
    required this.savingHandles,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && hasReachedStart) {
      return Center(
        child: Text(
          'No messages yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final rows = _buildRows();

    // Reversed so the list starts scrolled to the newest message at the bottom.
    // That makes "after" the top: extentAfter is the distance to the oldest row.
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < _loadOlderThreshold) {
          onLoadOlder();
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: rows.length + 1,
        itemBuilder: (context, index) {
          if (index == rows.length) return _buildHistoryHeader(context);

          return switch (rows[index]) {
            _MessageRow(:final message) => MessageBubble(
              key: ValueKey(message.id),
              message: message,
              loadPreview: loadPreview,
              onOpenImage: onOpenImage,
              onSaveFile: onSaveFile,
              onFailedTap: () => onFailedTap(message),
              isSaving: savingHandles.contains(message.media?.handle),
            ),
            _DateRow(:final day) => _DateSeparator(
              key: ValueKey(day),
              day: day,
            ),
          };
        },
      ),
    );
  }

  /// Newest first (the list is reversed), with a date separator above the
  /// first message of each day.
  List<_Row> _buildRows() {
    final rows = <_Row>[];
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      rows.add(_MessageRow(message));

      final day = _dayOf(message);
      if (i == 0 || _dayOf(messages[i - 1]) != day) rows.add(_DateRow(day));
    }
    return rows;
  }

  /// Top of the list: progress while loading, a marker at the start of the room,
  /// otherwise a button (scrolling can't trigger a load when the messages
  /// don't fill the screen).
  Widget _buildHistoryHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoadingOlder
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.secondary,
                ),
              )
            : hasReachedStart
            ? Text(
                'Beginning of the conversation',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            : TextButton(
                onPressed: onLoadOlder,
                child: const Text('Load older messages'),
              ),
      ),
    );
  }

  static DateTime _dayOf(MessageSummary message) {
    final time = DateTime.fromMillisecondsSinceEpoch(message.timestampMs);
    return DateTime(time.year, time.month, time.day);
  }
}

sealed class _Row {}

class _MessageRow extends _Row {
  final MessageSummary message;
  _MessageRow(this.message);
}

class _DateRow extends _Row {
  /// Local midnight.
  final DateTime day;
  _DateRow(this.day);
}

class _DateSeparator extends StatelessWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final DateTime day;

  const _DateSeparator({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          _label(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }

  /// "Today", "Yesterday", "Mon, 12 Oct", or "Mon, 12 Oct 2025" for other years.
  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Calendar-day difference; DST days aren't 24h, so don't use Duration.inDays.
    final daysAgo = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;

    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';

    final label =
        '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';
    return day.year == now.year ? label : '$label ${day.year}';
  }
}

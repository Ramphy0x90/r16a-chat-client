import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_composer.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_list.dart';
import 'package:r16a_chat_client/src/rust/api/messages.dart';
import 'package:r16a_chat_client/src/rust/api/rooms.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;

  /// Passed when navigating from the room list; fetched when null (direct link).
  final String? roomName;

  const RoomScreen({super.key, required this.roomId, this.roomName});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  static const _pageSize = 30;

  List<MessageSummary> _messages = [];
  String? _roomName;
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _hasReachedStart = false;
  bool _isSending = false;
  String? _errorMessage;
  StreamSubscription<List<MessageSummary>>? _timelineSubscription;

  @override
  void initState() {
    super.initState();
    _roomName = widget.roomName;
    if (_roomName == null) _loadRoomName();
    _watchTimeline();
  }

  @override
  void dispose() {
    _timelineSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: _roomName ?? '',
      child: Column(
        children: [
          Expanded(child: _buildBody()),
          MessageComposer(onSend: _handleSend, isSending: _isSending),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    return MessageList(
      messages: _messages,
      isLoadingOlder: _isLoadingOlder,
      hasReachedStart: _hasReachedStart,
      onLoadOlder: _loadOlder,
    );
  }

  /// Rust sends the whole list on every change (new, older, edited, decrypted),
  /// so there's nothing to merge here.
  void _watchTimeline() {
    var isFirst = true;
    _timelineSubscription =
        watchRoomTimeline(
          homeserverUrl: AppConstants.defaultHomeserverUrl,
          roomId: widget.roomId,
        ).listen(
          (messages) {
            if (!mounted) return;
            setState(() {
              _messages = messages;
              _errorMessage = null;
              _isLoading = false;
            });
            // The first emission is only what's cached locally, often little or
            // nothing. Fetch a page so the screen doesn't open empty.
            if (isFirst) {
              isFirst = false;
              _loadOlder();
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Failed to load messages: $e';
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _loadOlder() async {
    if (_isLoadingOlder || _hasReachedStart) return;
    setState(() => _isLoadingOlder = true);

    try {
      // Older messages arrive through the timeline stream.
      final reachedStart = await paginateBackwards(
        roomId: widget.roomId,
        count: _pageSize,
      );
      if (mounted) setState(() => _hasReachedStart = reachedStart);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load older messages: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  Future<void> _loadRoomName() async {
    try {
      final name = await getRoomName(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        roomId: widget.roomId,
      );
      if (mounted) setState(() => _roomName = name);
    } catch (_) {
      // Unknown room: the timeline stream reports the error in the body.
      if (mounted) setState(() => _roomName = 'Chat');
    }
  }

  Future<bool> _handleSend(String text) async {
    // Guard here, the composer's isSending prop lags a frame behind.
    if (_isSending) return false;
    setState(() => _isSending = true);

    try {
      await sendTextMessage(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        roomId: widget.roomId,
        body: text,
      );
      // The sent message shows up through the timeline like any other.
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

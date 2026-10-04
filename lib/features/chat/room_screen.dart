import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_composer.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_list.dart';
import 'package:r16a_chat_client/src/rust/api/messages.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  static const _messageLimit = 50;

  List<MessageSummary> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  StreamSubscription<MessageSummary>? _newMessagesSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe before loading history so nothing arriving in between is missed.
    _watchNewMessages();
    _loadMessages();
  }

  @override
  void dispose() {
    _newMessagesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: widget.roomName,
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
    return MessageList(messages: _messages);
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await getMessages(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        roomId: widget.roomId,
        limit: _messageLimit,
      );
      if (!mounted) return;
      setState(() {
        // Keep live messages that arrived while history was loading.
        final loadedIds = messages.map((m) => m.eventId).toSet();
        _messages = [
          ...messages,
          ..._messages.where((m) => !loadedIds.contains(m.eventId)),
        ];
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep showing what's already loaded; only go full-screen error when empty.
      if (_messages.isEmpty) {
        setState(() => _errorMessage = 'Failed to load messages: $e');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to refresh: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _watchNewMessages() {
    _newMessagesSubscription =
        watchRoomMessages(
          homeserverUrl: AppConstants.defaultHomeserverUrl,
          roomId: widget.roomId,
        ).listen(
          (message) {
            if (!mounted) return;
            if (_messages.any((m) => m.eventId == message.eventId)) return;
            setState(() => _messages = [..._messages, message]);
          },
          // Setup errors (e.g. unknown room) also fail _loadMessages, which shows them.
          onError: (Object _) {},
        );
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
      // The sent message shows up through the sync loop like any other.
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

import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';
import 'package:r16a_chat_client/features/chat/widgets/image_viewer.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_composer.dart';
import 'package:r16a_chat_client/features/chat/widgets/message_list.dart';
import 'package:r16a_chat_client/src/rust/api/media.dart';
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

  /// Per screen, not per room: a new screen for the same room can start
  /// before the old one is disposed (e.g. resizing across the breakpoint).
  static int _nextWatchId = 0;
  final int _watchId = _nextWatchId++;

  List<MessageSummary> _messages = [];
  String? _roomName;
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _hasReachedStart = false;
  bool _isSending = false;
  String? _errorMessage;
  StreamSubscription<List<MessageSummary>>? _timelineSubscription;

  /// Keyed by media handle so rebuilds reuse the same download.
  final Map<String, Future<Uint8List>> _previews = {};
  final Set<String> _savingHandles = {};

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
    // Rust can't tell the stream was cancelled until its next send, this
    // drops the room's timeline right away.
    unwatchRoomTimeline(watchId: _watchId);
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
      loadPreview: _loadPreview,
      onOpenImage: _openImage,
      onSaveFile: _saveFile,
      onUnsentTap: _showUnsentOptions,
      savingHandles: _savingHandles,
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
          watchId: _watchId,
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

  Future<Uint8List> _loadPreview(MediaInfo media) {
    return _previews.putIfAbsent(media.handle, () {
      final future = loadMediaPreview(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        handle: media.handle,
      );
      // Forget failures so the next rebuild retries instead of caching the error.
      future.then(
        (_) {},
        onError: (Object _) => _previews.remove(media.handle),
      );
      return future;
    });
  }

  void _openImage(MediaInfo media) {
    showDialog<void>(
      context: context,
      builder: (context) => ImageViewer(
        title: media.filename,
        image: loadMedia(
          homeserverUrl: AppConstants.defaultHomeserverUrl,
          handle: media.handle,
        ),
      ),
    );
  }

  Future<void> _saveFile(MediaInfo media) async {
    if (_savingHandles.contains(media.handle)) return;

    // Desktop only: file_selector has no save dialog on Android/iOS.
    final location = await getSaveLocation(suggestedName: media.filename);
    if (location == null || !mounted) return;

    setState(() => _savingHandles.add(media.handle));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await saveMedia(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        handle: media.handle,
        path: location.path,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Saved ${media.filename}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _savingHandles.remove(media.handle));
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
      // Only queues it (fast, also offline): the message shows up right away
      // through the timeline as "Sending…" and Rust sends it in the background.
      await sendTextMessage(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        roomId: widget.roomId,
        body: text,
      );
      return true;
    } catch (e) {
      _showSnackBar('Failed to send: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Failed: retry or delete. Still sending: delete only (it's retried
  /// automatically, but the user may not want to wait).
  Future<void> _showUnsentOptions(MessageSummary message) async {
    final canRetry = message.sendState == SendState.failed;
    final error = Theme.of(context).colorScheme.error;
    final retry = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRetry)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Try again'),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Delete message', style: TextStyle(color: error)),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
          ],
        ),
      ),
    );
    if (retry == null) return;

    try {
      if (retry) {
        await retrySend(roomId: widget.roomId, messageId: message.id);
      } else {
        final deleted = await deleteUnsent(
          roomId: widget.roomId,
          messageId: message.id,
        );
        if (!deleted) _showSnackBar('Too late, the message was already sent');
      }
    } catch (e) {
      _showSnackBar(retry ? 'Failed to retry: $e' : 'Failed to delete: $e');
    }
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

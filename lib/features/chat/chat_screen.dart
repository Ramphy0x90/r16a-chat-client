import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/src/rust/api/rooms.dart';

class ChatScreen extends StatefulWidget {
  /// The room open in the desktop detail pane, highlighted in the list.
  final String? selectedRoomId;

  const ChatScreen({super.key, this.selectedRoomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<RoomSummary> _rooms = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<RoomSummary>>? _roomsSubscription;

  @override
  void initState() {
    super.initState();
    _watchRooms();
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The app bar also keeps the content below the status bar on mobile.
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_rooms.isEmpty) {
      return const Center(child: Text('No chats yet'));
    }

    return ListView.builder(
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        return ListTile(
          title: Text(room.name),
          selected: room.id == widget.selectedRoomId,
          selectedTileColor: Theme.of(context).colorScheme.surface,
          selectedColor: Theme.of(context).colorScheme.onSurface,
          onTap: () => context.go(Routes.room(room.id), extra: room.name),
        );
      },
    );
  }

  /// Emits right away from the local store, then on every sync that touches a room.
  void _watchRooms() {
    _roomsSubscription =
        watchRooms(homeserverUrl: AppConstants.defaultHomeserverUrl).listen(
          (rooms) {
            if (!mounted) return;
            setState(() {
              _rooms = rooms;
              _errorMessage = null;
              _isLoading = false;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _errorMessage = "Failed to load rooms: $e";
              _isLoading = false;
            });
          },
        );
  }
}

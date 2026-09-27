import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/src/rust/api/rooms.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<RoomSummary> _rooms = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    return Scaffold(
      body: ListView.builder(
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return ListTile(
            title: Text(room.name),
            onTap: () {
              // navigate into the room, later
            },
          );
        },
      ),
    );
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await getRooms(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
      );
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load rooms: $e";
        _isLoading = false;
      });
    }
  }
}

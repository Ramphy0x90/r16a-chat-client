import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailScaffold(
      title: "Profile",
      child: Center(child: Text('Im profile screen')),
    );
  }
}

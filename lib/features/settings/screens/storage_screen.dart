import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';

class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailScaffold(
      title: "Storage",
      child: Center(child: Text('Im storage screen')),
    );
  }
}

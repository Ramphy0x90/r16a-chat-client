import 'package:flutter/material.dart';

class ZmeyProgress extends StatelessWidget {
  const ZmeyProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

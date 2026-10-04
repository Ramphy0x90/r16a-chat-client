import 'package:flutter/material.dart';

class ZmeyProgress extends StatelessWidget {
  /// Defaults to the theme's primary color.
  final Color? color;

  const ZmeyProgress({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

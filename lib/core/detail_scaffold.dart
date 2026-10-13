import 'package:flutter/material.dart';

/// Drill-down screen: AppBar's automatic back button (pops the route; its SVG
/// icon comes from `AppTheme`'s `actionIconTheme`).
class DetailScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const DetailScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

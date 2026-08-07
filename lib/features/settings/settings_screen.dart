import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// Profile --> [Username, profile pic]
    /// Security --> [Active sessions, authentication (email, pass change)]
    /// Customize --> [Theme, idk]
    /// Storage --> [Cache, idk]
    return const Scaffold(body: Center(child: Text('Im settings screen')));
  }
}

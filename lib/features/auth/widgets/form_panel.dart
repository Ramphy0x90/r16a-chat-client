import 'package:flutter/material.dart';

/// Widget for auth forms
class FormPanel extends StatefulWidget {
  final void Function(String username, String password) onSubmit;
  const FormPanel({super.key, required this.onSubmit});

  @override
  State<FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<FormPanel> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                TextField(controller: _usernameController),
                TextField(controller: _passwordController, obscureText: true),
                ElevatedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleSubmit() {
    widget.onSubmit(_usernameController.text, _passwordController.text);
  }
}

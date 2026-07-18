import 'package:flutter/material.dart';
import 'package:r16a_chat_client/features/auth/widgets/zmey_text_field.dart';

/// Widget for auth forms
class LoginForm extends StatefulWidget {
  final void Function(String username, String password) onSubmit;
  const LoginForm({super.key, required this.onSubmit});

  @override
  State<LoginForm> createState() => _FormPanelState();
}

class _FormPanelState extends State<LoginForm> {
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
    final colors = Theme.of(context);

    return Column(
      spacing: 40,
      children: [
        Column(
          spacing: 25,
          children: [
            ZmeyTextField(label: "Username", controller: _usernameController),
            ZmeyTextField(
              label: "Password",
              controller: _passwordController,
              obscureText: true,
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.colorScheme.primary,
            ),
            onPressed: _handleSubmit,
            child: Text(
              "Sign in",
              style: TextStyle(color: colors.colorScheme.surface),
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

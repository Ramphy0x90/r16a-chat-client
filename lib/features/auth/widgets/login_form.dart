import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/zmey_progress.dart';
import 'package:r16a_chat_client/core/zmey_text_field.dart';

/// Widget for auth forms
class LoginForm extends StatefulWidget {
  final void Function(String username, String password) onSubmit;
  final bool isLoading;
  final String? errorMsg;

  const LoginForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
    this.errorMsg,
  });

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
    final bool isLoginInProgress = widget.isLoading;

    return Column(
      spacing: 40,
      children: [
        Column(
          spacing: 25,
          children: [
            ZmeyTextField(
              label: "Username",
              controller: _usernameController,
              disabled: isLoginInProgress,
            ),
            ZmeyTextField(
              label: "Password",
              controller: _passwordController,
              disabled: isLoginInProgress,
              obscureText: true,
            ),
            if (widget.errorMsg != null && widget.errorMsg!.isNotEmpty)
              Text(
                widget.errorMsg!,
                style: TextStyle(color: colors.colorScheme.error),
              ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.colorScheme.primary,
            ),
            onPressed: isLoginInProgress ? null : _handleSubmit,
            child: isLoginInProgress
                ? const ZmeyProgress()
                : Text(
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

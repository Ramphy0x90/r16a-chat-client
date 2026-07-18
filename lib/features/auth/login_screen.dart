import 'package:flutter/material.dart';
import 'package:r16a_chat_client/features/auth/auth_scaffold.dart';
import 'package:r16a_chat_client/features/auth/widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: "Welcome back",
      subtitle: "Sign in to your account",
      formContent: LoginForm(onSubmit: (username, password) {}),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/features/auth/widgets/brand_panel.dart';
import 'package:r16a_chat_client/features/auth/widgets/form_panel.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(flex: 3, child: BrandPanel()),
          Expanded(
            flex: 6,
            child: FormPanel(
              onSubmit: (username, password) {
                // handle it here, in the parent
                print('Got: $username / $password');
              },
            ),
          ),
        ],
      ),
    );
  }
}

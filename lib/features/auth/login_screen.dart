import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/features/auth/auth_scaffold.dart';
import 'package:r16a_chat_client/features/auth/widgets/login_form.dart';
import 'package:r16a_chat_client/src/rust/api/auth.dart';
import 'package:r16a_chat_client/src/rust/api/recovery.dart';
import 'package:r16a_chat_client/src/rust/api/sync.dart';
import 'package:r16a_chat_client/services/session_storage.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: "Welcome back",
      subtitle: "Sign in to your account",
      formContent: LoginForm(
        onSubmit: _handleLogin,
        isLoading: _isLoading,
        errorMsg: _errorMsg,
      ),
    );
  }

  /// A backup exists but this new device can't read it yet: ask for the key.
  /// Any failure just skips the prompt (still reachable from Settings).
  Future<bool> _needsRecoveryKey() async {
    try {
      final status = await getRecoveryStatus(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
      );
      return status == RecoveryStatus.incomplete;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleLogin(String username, String password) async {
    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final sessionJson = await login(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        username: username,
        password: password,
      );

      await SessionStorage().saveSession(sessionJson);
      await startSync(homeserverUrl: AppConstants.defaultHomeserverUrl);
      final needsRecoveryKey = await _needsRecoveryKey();

      if (mounted) {
        context.go(needsRecoveryKey ? Routes.recover : Routes.chats);
      }
    } catch (e) {
      setState(() => _errorMsg = 'Login failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

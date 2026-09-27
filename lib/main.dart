import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/router.dart';
import 'src/rust/frb_generated.dart';
import 'theme/app_theme.dart';
import 'package:r16a_chat_client/services/session_storage.dart';
import 'package:r16a_chat_client/src/rust/api/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  final sessionJson = await SessionStorage().loadSession();
  if (sessionJson != null) {
    try {
      await restoreSession(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        sessionJson: sessionJson,
      );
    } catch (e) {
      await SessionStorage().clearSession();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

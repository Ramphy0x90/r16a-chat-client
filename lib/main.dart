import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/router.dart';
import 'src/rust/frb_generated.dart';
import 'theme/app_theme.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  await RustLib.init();
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

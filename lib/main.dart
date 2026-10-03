import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/router.dart';
import 'src/rust/frb_generated.dart';
import 'theme/app_theme.dart';
import 'package:r16a_chat_client/services/session_storage.dart';
import 'package:r16a_chat_client/src/rust/api/auth.dart';
import 'package:r16a_chat_client/src/rust/api/client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  final sessionJson = await SessionStorage().loadSession();

  // Persistent Matrix store (state + E2EE keys). Without a saved session the
  // store is stale: a fresh login gets a new device ID that the old crypto
  // store would reject, so wipe it before the client opens it.
  final supportDir = await getApplicationSupportDirectory();
  final storeDir = Directory('${supportDir.path}/matrix_store');
  if (sessionJson == null && await storeDir.exists()) {
    await storeDir.delete(recursive: true);
  }
  await setStore(
    path: storeDir.path,
    passphrase: await SessionStorage().loadOrCreateStorePassphrase(),
  );

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

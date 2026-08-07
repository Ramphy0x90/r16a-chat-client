import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/core/app_shell.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/features/auth/login_screen.dart';
import 'package:r16a_chat_client/features/chat/chat_screen.dart';
import 'package:r16a_chat_client/features/settings/screens/customize_screen.dart';
import 'package:r16a_chat_client/features/settings/screens/profile_screen.dart';
import 'package:r16a_chat_client/features/settings/screens/security_screen.dart';
import 'package:r16a_chat_client/features/settings/screens/storage_screen.dart';
import 'package:r16a_chat_client/features/settings/settings_screen.dart';
import 'package:r16a_chat_client/services/session_storage.dart';

final router = GoRouter(
  initialLocation: Routes.login,
  redirect: (context, state) async {
    final hasSession = await SessionStorage().loadSession() != null;
    final isLoginDestination = state.matchedLocation == Routes.login;

    if (!hasSession && !isLoginDestination) return Routes.login;
    if (hasSession && isLoginDestination) return Routes.chats;

    return null;
  },
  routes: [
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(screen: child),
      routes: [
        GoRoute(
          path: Routes.chats,
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: Routes.settingsProfile,
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: Routes.settingsSecurity,
              builder: (context, state) => const SecurityScreen(),
            ),
            GoRoute(
              path: Routes.settingsCustomize,
              builder: (context, state) => const CustomizeScreen(),
            ),
            GoRoute(
              path: Routes.settingsStorage,
              builder: (context, state) => const StorageScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

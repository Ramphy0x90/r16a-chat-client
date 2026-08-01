import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/features/auth/login_screen.dart';
import 'package:r16a_chat_client/features/chat/chat_screen.dart';
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
    GoRoute(
      path: Routes.chats,
      builder: (context, state) => const ChatScreen(),
    ),
  ],
);

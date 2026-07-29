import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/features/auth/login_screen.dart';
import 'package:r16a_chat_client/services/session_storage.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final hasSession = await SessionStorage().loadSession() != null;
    final isLoggingIn = state.matchedLocation == '/login';

    if (!hasSession && !isLoggingIn) return '/login';
    if (hasSession && isLoggingIn) return '/chats';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/chats',
      builder: (context, state) => const ChatListScreen(),
    ),
  ],
);

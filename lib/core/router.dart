import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/core/app_shell.dart';
import 'package:r16a_chat_client/core/breakpoints.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/master_detail_shell.dart';
import 'package:r16a_chat_client/features/auth/login_screen.dart';
import 'package:r16a_chat_client/features/chat/chat_screen.dart';
import 'package:r16a_chat_client/features/chat/room_screen.dart';
import 'package:r16a_chat_client/features/contacts/contacts_screen.dart';
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
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, screen: child),
      routes: [
        // Each section gets its own inner shell: on desktop it keeps the list
        // pane mounted next to the routed detail (see MasterDetailShell).
        ShellRoute(
          builder: (context, state, child) => MasterDetailShell(
            list: ChatScreen(selectedRoomId: _roomIdOf(state)),
            detail: child,
          ),
          routes: [
            GoRoute(
              path: Routes.chats,
              pageBuilder: (context, state) => _page(
                context,
                state,
                const MasterDetailHome(
                  list: ChatScreen(),
                  emptyMessage: 'Select a chat',
                ),
              ),
              routes: [
                GoRoute(
                  path: ":roomId",
                  pageBuilder: (context, state) => _page(
                    context,
                    state,
                    RoomScreen(
                      roomId: state.pathParameters['roomId']!,
                      roomName: state.extra as String?,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) =>
              MasterDetailShell(list: const ContactsScreen(), detail: child),
          routes: [
            GoRoute(
              path: Routes.contacts,
              pageBuilder: (context, state) => _page(
                context,
                state,
                const MasterDetailHome(
                  list: ContactsScreen(),
                  emptyMessage: 'Select a contact',
                ),
              ),
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => MasterDetailShell(
            list: SettingsScreen(selectedLocation: state.uri.path),
            detail: child,
          ),
          routes: [
            GoRoute(
              path: Routes.settings,
              pageBuilder: (context, state) => _page(
                context,
                state,
                const MasterDetailHome(
                  list: SettingsScreen(),
                  emptyMessage: 'Select a setting',
                ),
              ),
              routes: [
                GoRoute(
                  path: "profile",
                  pageBuilder: (context, state) =>
                      _page(context, state, const ProfileScreen()),
                ),
                GoRoute(
                  path: "security",
                  pageBuilder: (context, state) =>
                      _page(context, state, const SecurityScreen()),
                ),
                GoRoute(
                  path: "customize",
                  pageBuilder: (context, state) =>
                      _page(context, state, const CustomizeScreen()),
                ),
                GoRoute(
                  path: "storage",
                  pageBuilder: (context, state) =>
                      _page(context, state, const StorageScreen()),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Desktop: switching the detail pane (room to room) is instant. Mobile: the
/// platform's push transition.
Page<void> _page(BuildContext context, GoRouterState state, Widget child) {
  return isDesktopLayout(context)
      ? NoTransitionPage<void>(key: state.pageKey, child: child)
      : MaterialPage<void>(key: state.pageKey, child: child);
}

/// `/chats/<roomId>` -> roomId (path segments are already decoded).
String? _roomIdOf(GoRouterState state) {
  final segments = state.uri.pathSegments;
  return segments.length >= 2 && '/${segments[0]}' == Routes.chats
      ? segments[1]
      : null;
}

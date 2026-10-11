import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:r16a_chat_client/services/session_storage.dart';
import 'package:r16a_chat_client/src/rust/api/auth.dart';
import 'package:r16a_chat_client/src/rust/api/sync.dart';

class AppShell extends StatefulWidget {
  final Widget screen;

  const AppShell({super.key, required this.screen});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  SyncState _syncState = SyncState.idle;
  bool _isLoggingOut = false;
  StreamSubscription<SyncState>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    // The shell wraps every logged-in route, so it's the one place that sees
    // the sync loop stop (e.g. the session was revoked from another device).
    _syncSubscription = watchSyncState().listen((state) {
      if (mounted) setState(() => _syncState = state);
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 56, child: _Navbar()),
          Expanded(
            child: Column(
              children: [
                _SyncBanner(
                  state: _syncState,
                  isLoggingOut: _isLoggingOut,
                  onLogInAgain: _handleLogInAgain,
                ),
                Expanded(child: widget.screen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The token is already dead server-side, so no confirmation: there's
  /// nothing left to keep. Same steps as the settings logout.
  Future<void> _handleLogInAgain() async {
    setState(() => _isLoggingOut = true);
    try {
      await logout();
    } catch (_) {
      // Only deleting the local store can fail; main() wipes it on the next
      // start since no session is saved.
    }
    await SessionStorage().clearSession();
    if (mounted) context.go(Routes.login);
  }
}

class _SyncBanner extends StatelessWidget {
  final SyncState state;
  final bool isLoggingOut;
  final VoidCallback onLogInAgain;

  const _SyncBanner({
    required this.state,
    required this.isLoggingOut,
    required this.onLogInAgain,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return switch (state) {
      // Connecting is left out so a normal startup doesn't flash a banner;
      // offline startups switch to disconnected after the first failed request.
      SyncState.idle || SyncState.connecting || SyncState.connected =>
        const SizedBox.shrink(),
      SyncState.disconnected => _bar(
        colors.surface,
        Text(
          'Offline, reconnecting…',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      ),
      SyncState.sessionExpired => _bar(
        colors.surface,
        Row(
          children: [
            Expanded(
              child: Text(
                'You were logged out on this device.',
                style: TextStyle(color: colors.error),
              ),
            ),
            TextButton(
              onPressed: isLoggingOut ? null : onLogInAgain,
              child: const Text('Log in again'),
            ),
          ],
        ),
      ),
    };
  }

  Widget _bar(Color background, Widget child) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: child,
    );
  }
}

class _Navbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsetsGeometry.only(top: 10),
        child: Column(
          children: [
            _NavbarIcon(
              iconPath: 'assets/icons/message.svg',
              isActive: currentPath.startsWith(Routes.chats),
              onTap: () => context.go(Routes.chats),
            ),
            _NavbarIcon(
              iconPath: 'assets/icons/settings.svg',
              isActive: currentPath.startsWith(Routes.settings),
              onTap: () => context.go(Routes.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavbarIcon extends StatelessWidget {
  final double iconSize = 25;

  final String iconPath;
  final bool isActive;
  final VoidCallback onTap;

  const _NavbarIcon({
    required this.iconPath,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      icon: SvgPicture.asset(
        iconPath,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(
          isActive ? colors.secondary : colors.onSurfaceVariant,
          BlendMode.srcIn,
        ),
      ),
      style: ButtonStyle(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return colors.secondary.withValues(alpha: 0.1);
          }
          return null;
        }),
      ),
      onPressed: onTap,
    );
  }
}

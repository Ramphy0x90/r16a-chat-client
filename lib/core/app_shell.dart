import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/breakpoints.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/desktop_shell.dart';
import 'package:r16a_chat_client/core/mobile_shell.dart';
import 'package:r16a_chat_client/core/nav_section.dart';
import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/services/session_storage.dart';
import 'package:r16a_chat_client/src/rust/api/auth.dart';
import 'package:r16a_chat_client/src/rust/api/sync.dart';

/// Wraps every logged-in route. Owns the sync status (banner) and navigation
/// between sections; the layout itself is [MobileShell] or [DesktopShell].
class AppShell extends StatefulWidget {
  /// Current path, e.g. `/chats/!abc:server`.
  final String location;
  final Widget screen;

  const AppShell({super.key, required this.location, required this.screen});

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
    final selected = NavSection.fromLocation(widget.location);
    // Connecting is left out so a normal startup doesn't flash a banner;
    // offline startups switch to disconnected after the first failed request.
    final banner = switch (_syncState) {
      SyncState.disconnected || SyncState.sessionExpired => _SyncBanner(
        state: _syncState,
        isLoggingOut: _isLoggingOut,
        onLogInAgain: _handleLogInAgain,
      ),
      SyncState.idle || SyncState.connecting || SyncState.connected => null,
    };

    if (isDesktopLayout(context)) {
      return DesktopShell(
        banner: banner,
        selected: selected,
        onSelected: _handleSectionSelected,
        child: widget.screen,
      );
    }
    return MobileShell(
      banner: banner,
      selected: selected,
      showDock: NavSection.isTopLevel(widget.location),
      onSelected: _handleSectionSelected,
      child: widget.screen,
    );
  }

  void _handleSectionSelected(NavSection section) {
    context.go(section.route);
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
      // AppShell doesn't build the banner in these states.
      SyncState.idle ||
      SyncState.connecting ||
      SyncState.connected => const SizedBox.shrink(),
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

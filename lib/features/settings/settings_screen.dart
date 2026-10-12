import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/features/settings/widgets/logout_tile.dart';
import 'package:r16a_chat_client/features/settings/widgets/setting_tile.dart';
import 'package:r16a_chat_client/services/session_storage.dart';
import 'package:r16a_chat_client/src/rust/api/auth.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  /// Current path, to highlight the open sub-screen in the desktop list pane.
  final String? selectedLocation;

  const SettingsScreen({super.key, this.selectedLocation});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    // The app bar also keeps the content below the status bar on mobile; a
    // ListView (not a Column) so it scrolls and ends above the mobile dock.
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SettingTile(
            title: 'Profile',
            iconPath: 'assets/icons/profile.svg',
            onTap: () => context.go(Routes.settingsProfile),
            selected: widget.selectedLocation == Routes.settingsProfile,
          ),
          SettingTile(
            title: 'Security',
            iconPath: 'assets/icons/security.svg',
            onTap: () => context.go(Routes.settingsSecurity),
            selected: widget.selectedLocation == Routes.settingsSecurity,
          ),
          SettingTile(
            title: 'Customize',
            iconPath: 'assets/icons/customize.svg',
            onTap: () => context.go(Routes.settingsCustomize),
            selected: widget.selectedLocation == Routes.settingsCustomize,
          ),
          SettingTile(
            title: 'Storage',
            iconPath: 'assets/icons/storage.svg',
            onTap: () => context.go(Routes.settingsStorage),
            selected: widget.selectedLocation == Routes.settingsStorage,
          ),
          LogoutTile(isLoading: _isLoggingOut, onTap: _handleLogout),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    if (!await showLogoutConfirmDialog(context) || !mounted) return;

    setState(() => _isLoggingOut = true);
    final messenger = ScaffoldMessenger.of(context);

    String? error;
    try {
      await logout();
    } catch (e) {
      // Rust has already dropped the client, so the session is dead either way:
      // go to login anyway. Only deleting the local store failed, and main()
      // wipes it on the next start (no session saved).
      error =
          'Logged out, but local data couldn\'t be fully cleared. '
          'Restart the app before logging in again. ($e)';
    }
    await SessionStorage().clearSession();

    if (mounted) context.go(Routes.login);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}

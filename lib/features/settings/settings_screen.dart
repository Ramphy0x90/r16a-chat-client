import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/features/settings/widgets/setting_tile.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SettingTile(
            title: 'Profile',
            iconPath: 'assets/icons/profile.svg',
            onTap: () => context.go(Routes.settingsProfile),
          ),
          SettingTile(
            title: 'Security',
            iconPath: 'assets/icons/security.svg',
            onTap: () => context.go(Routes.settingsSecurity),
          ),
          SettingTile(
            title: 'Customize',
            iconPath: 'assets/icons/customize.svg',
            onTap: () => context.go(Routes.settingsCustomize),
          ),
          SettingTile(
            title: 'Storage',
            iconPath: 'assets/icons/storage.svg',
            onTap: () => context.go(Routes.settingsStorage),
          ),
        ],
      ),
    );
  }
}

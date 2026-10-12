import 'package:r16a_chat_client/core/constants.dart';

/// Top-level destinations, shown in the mobile dock and the desktop rail.
enum NavSection {
  chats('Chats', Routes.chats, 'assets/icons/message.svg'),
  // Stand-in icon until assets/icons has a contacts icon.
  contacts('Contacts', Routes.contacts, 'assets/icons/profile.svg'),
  settings('Settings', Routes.settings, 'assets/icons/settings.svg');

  final String label;
  final String route;
  final String iconPath;

  const NavSection(this.label, this.route, this.iconPath);

  /// The section a location belongs to, e.g. `/chats/!abc` -> chats.
  static NavSection? fromLocation(String path) {
    for (final section in values) {
      if (path == section.route || path.startsWith('${section.route}/')) {
        return section;
      }
    }
    return null;
  }

  /// True on the section's own screen (`/chats`), false on sub-screens
  /// (`/chats/!abc`). The mobile dock only shows on top-level screens.
  static bool isTopLevel(String path) =>
      values.any((section) => section.route == path);
}

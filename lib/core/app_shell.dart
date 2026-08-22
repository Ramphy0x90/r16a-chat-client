import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppShell extends StatelessWidget {
  final Widget screen;

  const AppShell({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 56, child: _Navbar()),
          Expanded(child: screen),
        ],
      ),
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
              isActive: currentPath == Routes.chats,
              onTap: () => context.go(Routes.chats),
            ),
            _NavbarIcon(
              iconPath: 'assets/icons/settings.svg',
              isActive: currentPath == Routes.settings,
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
          isActive ? colors.primary : colors.onSurfaceVariant,
          BlendMode.srcIn,
        ),
      ),
      style: ButtonStyle(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return colors.primary.withValues(alpha: 0.1);
          }
          return null;
        }),
      ),
      onPressed: onTap,
    );
  }
}

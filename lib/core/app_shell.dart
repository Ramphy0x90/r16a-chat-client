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
  final double iconSize = 25;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/images/message.svg',
              width: iconSize,
              height: iconSize,
            ),
            onPressed: () => context.go(Routes.chats),
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/images/settings.svg',
              width: iconSize,
              height: iconSize,
            ),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingTile extends StatelessWidget {
  final double iconSize = 18;

  final String title;
  final String iconPath;
  final VoidCallback onTap;

  /// Highlighted when its screen is open in the desktop detail pane.
  final bool selected;

  const SettingTile({
    super.key,
    required this.title,
    required this.iconPath,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: SvgPicture.asset(
        'assets/icons/arrow-go.svg',
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSurfaceVariant,
          BlendMode.srcIn,
        ),
      ),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.onSurface,
      onTap: onTap,
    );
  }
}

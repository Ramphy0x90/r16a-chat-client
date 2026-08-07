import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingTile extends StatelessWidget {
  final double iconSize = 18;

  final String title;
  final String iconPath;
  final VoidCallback onTap;

  const SettingTile({
    super.key,
    required this.title,
    required this.iconPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      /// MIN: Idk yet if I want icon on the left
      /// leading: SvgPicture.asset(
      ///   iconPath,
      ///   width: iconSize,
      ///   height: iconSize,
      ///   colorFilter: ColorFilter.mode(
      ///     Theme.of(context).colorScheme.onSurfaceVariant,
      ///     BlendMode.srcIn,
      ///   ),
      /// ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

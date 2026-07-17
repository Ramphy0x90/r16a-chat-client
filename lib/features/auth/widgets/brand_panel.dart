import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget for brand panel, it shows logo and app name
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/logo-light.svg',
            width: 128,
            height: 128,
          ),
          Text(
            AppConstants.appName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight(800)),
          ),
        ],
      ),
    );
  }
}

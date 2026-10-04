import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/zmey_progress.dart';

class ProfileAvatar extends StatelessWidget {
  static const double size = 112;

  final Uint8List? bytes;

  /// Shown when there's no avatar image.
  final String fallbackInitial;
  final VoidCallback onTap;
  final bool isLoading;

  const ProfileAvatar({
    super.key,
    required this.bytes,
    required this.fallbackInitial,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Decode at display size, not at whatever size the image happens to be.
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

    return Tooltip(
      message: 'Change profile picture',
      child: Semantics(
        button: true,
        enabled: !isLoading,
        label: 'Change profile picture',
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onTap,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: size / 2,
                  backgroundColor: colors.secondary,
                  foregroundImage: bytes != null
                      ? ResizeImage(
                          MemoryImage(bytes!),
                          width: decodeSize,
                          height: decodeSize,
                          policy: ResizeImagePolicy.fit,
                        )
                      : null,
                  child: Text(
                    fallbackInitial,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(color: colors.surface),
                  ),
                ),
                if (isLoading)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface.withValues(alpha: 0.6),
                    ),
                    alignment: Alignment.center,
                    child: ZmeyProgress(color: colors.secondary),
                  )
                else
                  // Secondary, not primary: maroon on the dark background is invisible.
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.secondary,
                      child: Icon(Icons.edit, size: 16, color: colors.surface),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

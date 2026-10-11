import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/src/rust/api/media.dart';

/// Inline image preview in a message bubble. The box is sized from the image's
/// declared dimensions before it loads, so the list doesn't jump.
class ImageAttachment extends StatelessWidget {
  static const _maxWidth = 280.0;
  static const _maxHeight = 320.0;
  static const _fallbackSize = Size(240, 180);

  final MediaInfo media;

  /// Should return the same future for the same media across rebuilds.
  final Future<Uint8List> Function(MediaInfo media) loadPreview;
  final VoidCallback onOpen;

  const ImageAttachment({
    super.key,
    required this.media,
    required this.loadPreview,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = _boxSize();
    final cacheWidth = (size.width * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Semantics(
      image: true,
      button: true,
      label: 'Image ${media.filename}, open',
      child: GestureDetector(
        onTap: onOpen,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.fromSize(
              size: size,
              child: FutureBuilder<Uint8List>(
                future: loadPreview(media),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _placeholder(colors, 'Couldn\'t load image');
                  }
                  if (!snapshot.hasData) {
                    return ColoredBox(
                      color: colors.onSurface.withValues(alpha: 0.05),
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    // Decode at display size, not the (possibly huge) source size.
                    cacheWidth: cacheWidth,
                    gaplessPlayback: true,
                    errorBuilder: (context, _, _) =>
                        _placeholder(colors, 'Can\'t display this image'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Size _boxSize() {
    final width = media.width;
    final height = media.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return _fallbackSize;
    }

    // Clamp extreme panoramas / tall screenshots, BoxFit.cover crops the rest.
    final aspect = (width / height).clamp(0.4, 3.0);
    var boxWidth = width.toDouble().clamp(80.0, _maxWidth);
    var boxHeight = boxWidth / aspect;
    if (boxHeight > _maxHeight) {
      boxHeight = _maxHeight;
      boxWidth = boxHeight * aspect;
    }
    return Size(boxWidth, boxHeight);
  }

  Widget _placeholder(ColorScheme colors, String text) {
    return ColoredBox(
      color: colors.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

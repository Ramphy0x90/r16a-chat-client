import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Full-screen image with pinch/scroll zoom. Shown as a dialog by the room screen.
class ImageViewer extends StatelessWidget {
  final String title;
  final Future<Uint8List> image;

  const ImageViewer({super.key, required this.title, required this.image});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, overflow: TextOverflow.ellipsis),
        ),
        body: FutureBuilder<Uint8List>(
          future: image,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Couldn\'t load image: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: colors.secondary),
              );
            }
            return InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  snapshot.data!,
                  errorBuilder: (context, _, _) => const Text(
                    'Can\'t display this image',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

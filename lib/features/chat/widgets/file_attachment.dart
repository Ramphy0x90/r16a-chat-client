import 'package:flutter/material.dart';
import 'package:r16a_chat_client/src/rust/api/media.dart';

/// File row in a message bubble: name, size and a save button.
class FileAttachment extends StatelessWidget {
  final MediaInfo media;
  final bool isSaving;
  final VoidCallback onSave;

  /// Own bubbles sit on the accent color, where onSurfaceVariant is too faint.
  final bool isOwn;

  const FileAttachment({
    super.key,
    required this.media,
    required this.isSaving,
    required this.onSave,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mutedColor = isOwn ? colors.onSurface : colors.onSurfaceVariant;
    final size = media.sizeBytes;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Icon(Icons.insert_drive_file_outlined, color: mutedColor),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media.filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurface),
              ),
              if (size != null)
                Text(
                  _formatSize(size),
                  style: textTheme.labelSmall?.copyWith(color: mutedColor),
                ),
            ],
          ),
        ),
        isSaving
            ? SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              )
            : IconButton(
                tooltip: 'Save',
                icon: Icon(Icons.download, color: colors.onSurface),
                onPressed: onSave,
              ),
      ],
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

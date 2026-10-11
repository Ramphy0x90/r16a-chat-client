import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';
import 'package:r16a_chat_client/features/settings/widgets/theme_mode_picker.dart';
import 'package:r16a_chat_client/services/theme_settings.dart';

class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key});

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  /// The tiles stay readable on wide (desktop) panes instead of stretching.
  static const _maxContentWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DetailScaffold(
      title: 'Customize',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'APPEARANCE',
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeSettings.mode,
                builder: (context, mode, _) =>
                    ThemeModePicker(selected: mode, onChanged: _handleChange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "System follows your device's light or dark setting.",
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChange(ThemeMode mode) async {
    try {
      await ThemeSettings.save(mode);
    } catch (e) {
      // The new mode is already applied, only remembering it failed.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save the theme choice: $e")),
        );
      }
    }
  }
}

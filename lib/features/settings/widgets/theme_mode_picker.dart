import 'package:flutter/material.dart';
import 'package:r16a_chat_client/theme/colors.dart';

/// System / Light / Dark tiles, each with a small preview of the chat in that
/// mode. The previews use fixed palette colors (not the current theme) so they
/// always show what the option looks like.
class ThemeModePicker extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        for (final mode in ThemeMode.values)
          Expanded(
            child: _ThemeTile(
              label: _label(mode),
              selected: mode == selected,
              onTap: () => onChanged(mode),
              preview: switch (mode) {
                ThemeMode.system => const _SystemPreview(),
                ThemeMode.light => const _ModePreview(
                  background: ZmeyColors.lightBg,
                  bubble: ZmeyColors.lightSurface,
                  ownBubble: ZmeyColors.lightAccentMaroon,
                ),
                ThemeMode.dark => const _ModePreview(
                  background: ZmeyColors.darkBg,
                  bubble: ZmeyColors.darkSurface,
                  ownBubble: ZmeyColors.darkAccentMaroon,
                ),
              },
            ),
          ),
      ],
    );
  }

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final Widget preview;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colors.secondary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(height: 88, child: preview),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                  child: Row(
                    spacing: 8,
                    children: [
                      _RadioDot(selected: selected),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.secondary : colors.onSurfaceVariant;

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            )
          : null,
    );
  }
}

/// Three message bars: incoming, own (right-aligned), incoming.
class _ModePreview extends StatelessWidget {
  final Color background;
  final Color bubble;
  final Color ownBubble;

  const _ModePreview({
    required this.background,
    required this.bubble,
    required this.ownBubble,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            _Bar(width: 44, color: bubble),
            Align(
              alignment: Alignment.centerRight,
              child: _Bar(width: 36, color: ownBubble),
            ),
            _Bar(width: 56, color: bubble),
          ],
        ),
      ),
    );
  }
}

/// Light half on the left (incoming bars), dark half on the right (own bar).
class _SystemPreview extends StatelessWidget {
  const _SystemPreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: ZmeyColors.lightBg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: const [
                  _Bar(width: 30, color: ZmeyColors.lightSurface),
                  SizedBox(height: 10),
                  _Bar(width: 30, color: ZmeyColors.lightSurface),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: ZmeyColors.darkBg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 6,
                children: const [
                  SizedBox(height: 10),
                  _Bar(width: 30, color: ZmeyColors.darkAccentMaroon),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final Color color;

  const _Bar({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    // Shrinks on very narrow tiles instead of overflowing.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

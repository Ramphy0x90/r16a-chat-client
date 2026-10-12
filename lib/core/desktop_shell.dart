import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:r16a_chat_client/core/nav_section.dart';

/// Desktop layout: side rail, then the section's content (usually a
/// [MasterDetailShell] with list and detail panes).
class DesktopShell extends StatelessWidget {
  final Widget child;

  /// Sync status banner, null when there's nothing to show.
  final Widget? banner;
  final NavSection? selected;
  final ValueChanged<NavSection> onSelected;

  const DesktopShell({
    super.key,
    required this.child,
    required this.banner,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final banner = this.banner;
    return Scaffold(
      body: Row(
        children: [
          _NavRail(selected: selected, onSelected: onSelected),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                ?banner,
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  static const _width = 72.0;

  final NavSection? selected;
  final ValueChanged<NavSection> onSelected;

  const _NavRail({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    // Logo files are named after their stroke color: maroon on light, gold on dark.
    final logo = Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/logo-light.svg'
        : 'assets/images/logo-dark.svg';

    return SizedBox(
      width: _width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          spacing: 8,
          children: [
            SvgPicture.asset(
              logo,
              width: 36,
              height: 36,
              semanticsLabel: 'Zmey',
            ),
            const SizedBox(height: 16),
            for (final section in NavSection.values)
              _RailItem(
                section: section,
                isSelected: section == selected,
                onTap: () => onSelected(section),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final NavSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isSelected ? colors.secondary : colors.onSurfaceVariant;

    return Tooltip(
      message: section.label,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: section.label,
        excludeSemantics: true,
        child: Material(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 40,
              child: Center(
                child: SvgPicture.asset(
                  section.iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:r16a_chat_client/core/nav_section.dart';

/// Mobile layout: one screen at a time, with a floating dock over the content
/// on the top-level screens (hidden on sub-screens like an open room).
class MobileShell extends StatelessWidget {
  static const _dockHeight = 64.0;
  static const _dockBottomGap = 16.0;

  final Widget child;

  /// Sync status banner, null when there's nothing to show.
  final Widget? banner;
  final NavSection? selected;
  final bool showDock;
  final ValueChanged<NavSection> onSelected;

  const MobileShell({
    super.key,
    required this.child,
    required this.banner,
    required this.selected,
    required this.showDock,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    var content = child;

    if (showDock) {
      // Scroll views add the bottom padding by default, so lists can scroll
      // their last item out from under the dock.
      content = MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(
            bottom: mediaQuery.padding.bottom + _dockHeight + _dockBottomGap,
          ),
        ),
        child: content,
      );
    }

    final banner = this.banner;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (banner != null) SafeArea(bottom: false, child: banner),
                Expanded(
                  // The banner already sits below the status bar.
                  child: banner != null
                      ? MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: content,
                        )
                      : content,
                ),
              ],
            ),
          ),
          if (showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: mediaQuery.padding.bottom + _dockBottomGap,
              child: Center(
                child: _FloatingDock(
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingDock extends StatelessWidget {
  final NavSection? selected;
  final ValueChanged<NavSection> onSelected;

  const _FloatingDock({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            for (final section in NavSection.values)
              _DockItem(
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

class _DockItem extends StatelessWidget {
  final NavSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = isSelected ? colors.secondary : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: section.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? theme.scaffoldBackgroundColor : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 80,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                SvgPicture.asset(
                  section.iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
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

import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/breakpoints.dart';
import 'package:r16a_chat_client/core/empty_pane.dart';

/// Per-section shell (chats, contacts, settings). Desktop: the list pane stays
/// mounted next to the routed detail, so it keeps its state (scroll position,
/// stream subscription) while the detail changes. Mobile: only the routed page;
/// the list is itself a route there (see [MasterDetailHome]).
class MasterDetailShell extends StatelessWidget {
  static const listPaneWidth = 360.0;

  final Widget list;

  /// The routed page (go_router's nested navigator).
  final Widget detail;

  const MasterDetailShell({
    super.key,
    required this.list,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return detail;

    return Row(
      children: [
        SizedBox(width: listPaneWidth, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

/// The section's own route (`/chats`): the list on mobile, a placeholder in the
/// detail pane on desktop (the list is already shown by [MasterDetailShell]).
/// Decided at build time, so resizing across the breakpoint switches correctly.
class MasterDetailHome extends StatelessWidget {
  final Widget list;
  final String emptyMessage;

  const MasterDetailHome({
    super.key,
    required this.list,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return isDesktopLayout(context) ? EmptyPane(message: emptyMessage) : list;
  }
}

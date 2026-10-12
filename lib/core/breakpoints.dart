import 'package:flutter/widgets.dart';

/// From this window width on, the app uses the desktop layout: side rail plus
/// list/detail panes. Below it, the mobile layout: one screen at a time with a
/// floating dock. 840 is Material's "expanded" size class; the two panes need
/// roughly 72 (rail) + 360 (list) + 400 (detail).
const double desktopBreakpoint = 840;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

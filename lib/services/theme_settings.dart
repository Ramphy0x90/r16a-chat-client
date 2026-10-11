import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / system choice. A device preference, not tied to the account,
/// so it survives logout. Plain shared_preferences: nothing secret here.
class ThemeSettings {
  static const _key = 'theme_mode';

  /// The app's current mode; `MyApp` rebuilds `MaterialApp` when it changes.
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Call once in `main()` before `runApp`, so the first frame has the right theme.
  static Future<void> load() async {
    final stored = await SharedPreferencesAsync().getString(_key);
    mode.value = ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  /// Applies right away, then persists.
  static Future<void> save(ThemeMode value) async {
    mode.value = value;
    await SharedPreferencesAsync().setString(_key, value.name);
  }
}

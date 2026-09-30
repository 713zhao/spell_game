import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide Parent Mode flag (persisted as `parent_mode`). Widgets such as
/// the bottom nav listen to it so the menu changes as soon as it's toggled.
class ParentMode {
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool('parent_mode') ?? false;
  }

  static Future<void> set(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('parent_mode', value);
  }
}

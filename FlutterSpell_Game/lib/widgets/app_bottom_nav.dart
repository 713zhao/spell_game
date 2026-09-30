import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../services/parent_mode.dart';

/// Bottom navigation shared by the main screens. Shows the kid tabs
/// normally and the parent tabs (Add Words / Labels / Profile) when
/// Parent Mode is on. [current] is the route of the hosting screen.
class AppBottomNav extends StatelessWidget {
  final String current;
  const AppBottomNav({super.key, required this.current});

  static const _kid = [
    ('/', Icons.home, 'Home'),
    ('/world-map', Icons.map, 'World Map'),
    ('/backpack', Icons.backpack, 'Backpack'),
    ('/progress', Icons.trending_up, 'Progress'),
    ('/profile', Icons.person, 'Profile'),
  ];
  static const _parent = [
    ('/parent-words', Icons.playlist_add, 'Add Words'),
    ('/parent-labels', Icons.label, 'Labels'),
    ('/profile', Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ParentMode.enabled,
      builder: (context, parent, _) {
        final tabs = parent ? _parent : _kid;
        final found = tabs.indexWhere((t) => t.$1 == current);
        return BottomNavigationBar(
          currentIndex: found < 0 ? 0 : found,
          type: BottomNavigationBarType.fixed,
          backgroundColor: DuolingoColors.backgroundWhite,
          selectedItemColor: found < 0
              ? DuolingoColors.navInactiveGray
              : DuolingoColors.primaryGreen,
          unselectedItemColor: DuolingoColors.navInactiveGray,
          items: [
            for (final t in tabs)
              BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3),
          ],
          onTap: (i) {
            final route = tabs[i].$1;
            if (route != current) {
              Navigator.of(context).pushReplacementNamed(route);
            }
          },
        );
      },
    );
  }
}

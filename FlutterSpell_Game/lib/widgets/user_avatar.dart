import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../utils/avatar_color.dart';

/// A colorful circular avatar shown wherever a user's identity appears
/// (top-right account button, login quick-pick, profile header). The
/// background color is deterministic per username (see [avatarColorFor]),
/// so the same person always gets the same color everywhere. Shows
/// [cosmeticEmoji] instead of the initial letter when one is equipped.
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? cosmeticEmoji;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 56,
    this.cosmeticEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = cosmeticEmoji;
    final showEmoji = emoji != null && emoji.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColorFor(name),
      ),
      alignment: Alignment.center,
      child: Text(
        showEmoji ? emoji : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: name.isEmpty
              ? DuolingoColors.darkText
              : DuolingoColors.backgroundWhite,
        ),
      ),
    );
  }
}

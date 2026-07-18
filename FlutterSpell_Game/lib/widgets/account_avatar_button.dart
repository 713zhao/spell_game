import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';

/// Top-right account entry point, added to every screen's app bar except
/// mid-session screens (study, boss battle) and Profile itself. Logged
/// out: a plain sign-in icon that opens the login screen. Logged in: a
/// circle with the username's first letter that opens a small menu
/// (View Profile / Switch User).
class AccountAvatarButton extends StatelessWidget {
  const AccountAvatarButton({super.key});

  static const double _size = DuolingoSpacing.miniTouchTarget;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    if (!provider.isLoggedIn) {
      return Padding(
        padding: EdgeInsets.only(right: DuolingoSpacing.md),
        child: IconButton(
          icon: Container(
            width: _size,
            height: _size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DuolingoColors.neutralGray,
            ),
            child: const Icon(
              Icons.person_outline,
              color: DuolingoColors.bodyText,
            ),
          ),
          tooltip: 'Sign in',
          onPressed: () => Navigator.of(context).pushNamed('/login'),
        ),
      );
    }

    final initial =
        provider.userName.isNotEmpty ? provider.userName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.only(right: DuolingoSpacing.md),
      child: GestureDetector(
        onTap: () => _showAccountMenu(context),
        child: Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: DuolingoColors.primaryGreen,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: DuolingoColors.backgroundWhite,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx,
        0,
      ),
      items: const [
        PopupMenuItem(value: 'profile', child: Text('View Profile')),
        PopupMenuItem(value: 'switch', child: Text('Switch User')),
      ],
    );

    if (!context.mounted) return;
    if (selection == 'profile') {
      Navigator.of(context).pushNamed('/profile');
    } else if (selection == 'switch') {
      await context.read<GameProvider>().logout();
      if (!context.mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/utils/lesson_label_filter.dart';

/// Chip row for filtering lessons by label type: "All" plus one chip per
/// entry in [types]. [selected] null means "All". Renders nothing when
/// there's only one type, since there's nothing to choose between.
class LabelTypeFilterBar extends StatelessWidget {
  final List<String> types;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const LabelTypeFilterBar({
    Key? key,
    required this.types,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (types.length < 2) return const SizedBox.shrink();
    return Wrap(
      spacing: DuolingoSpacing.sm,
      runSpacing: DuolingoSpacing.xs,
      children: [
        _chip('All', selected == null, () => onSelected(null)),
        for (final t in types)
          _chip(
            '${labelTypeEmoji(t)} ${labelTypeName(t)}',
            selected == t,
            () => onSelected(t),
          ),
      ],
    );
  }

  Widget _chip(String text, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(
        text,
        style: DuolingoTextStyles.label.copyWith(
          color: isSelected ? Colors.white : DuolingoColors.darkText,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: DuolingoColors.primaryGreen,
      backgroundColor: DuolingoColors.backgroundWhite,
      onSelected: (_) => onTap(),
    );
  }
}

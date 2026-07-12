import 'package:flutter/material.dart';
import '../models/game_models.dart';

class CosmeticCard extends StatelessWidget {
  final Unlockable cosmetic;
  final VoidCallback? onRedeem;
  final VoidCallback? onEquip;
  final bool isOwned;

  const CosmeticCard({
    required this.cosmetic,
    required this.isOwned,
    this.onRedeem,
    this.onEquip,
  });

  Color _getRarityColor() {
    switch (cosmetic.rarity.toLowerCase()) {
      case 'common':
        return Colors.grey[400]!;
      case 'rare':
        return Colors.blue[400]!;
      case 'epic':
        return Colors.purple[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  IconData _getTypeIcon() {
    switch (cosmetic.type.toLowerCase()) {
      case 'avatar':
        return Icons.face;
      case 'theme':
        return Icons.palette;
      case 'effect':
        return Icons.sparkles;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: isOwned && cosmetic.equipped ? null : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with rarity border
            Container(
              decoration: BoxDecoration(
                color: _getRarityColor().withOpacity(0.2),
                border: Border(
                  top: BorderSide(
                    color: _getRarityColor(),
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cosmetic.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cosmetic.type.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: _getRarityColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _getTypeIcon(),
                        color: _getRarityColor(),
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRarityColor().withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cosmetic.rarity.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getRarityColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Center content (icon placeholder)
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: Center(
                  child: Icon(
                    _getTypeIcon(),
                    size: 48,
                    color: _getRarityColor().withOpacity(0.3),
                  ),
                ),
              ),
            ),

            // Footer with action button or owned indicator
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isOwned) ...[
                    Text(
                      '${cosmetic.pointsCost} points',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: onRedeem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getRarityColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Redeem'),
                    ),
                  ] else ...[
                    if (cosmetic.equipped)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[700],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Equipped',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: onEquip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Equip'),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

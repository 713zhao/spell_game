import 'package:flutter/material.dart';

class AchievementBadge extends StatelessWidget {
  final String icon;
  final String name;
  final String description;
  final bool unlocked;
  final double progress;
  final String? progressLabel;

  const AchievementBadge({
    required this.icon,
    required this.name,
    required this.description,
    required this.unlocked,
    this.progress = 0.0,
    this.progressLabel,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: unlocked ? Colors.amber[50] : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked ? Colors.amber[300] : Colors.grey[400],
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Name and Description
            Text(
              name,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Progress Bar
            if (!unlocked && progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue[400]!,
                        ),
                      ),
                    ),
                    if (progressLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          progressLabel!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),

            // Unlocked/Locked Badge
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: unlocked ? Colors.green[100] : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unlocked ? 'Unlocked' : 'Locked',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: unlocked ? Colors.green[700] : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

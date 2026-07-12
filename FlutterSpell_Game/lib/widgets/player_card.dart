import 'package:flutter/material.dart';
import '../models/game_models.dart';

class PlayerCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const PlayerCard({
    required this.entry,
    this.isCurrentUser = false,
    this.onTap,
  });

  String getMedalEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final medal = getMedalEmoji(entry.rank);

    return Card(
      color: isCurrentUser ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Rank with medal
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    if (medal.isNotEmpty)
                      Text(
                        medal,
                        style: const TextStyle(fontSize: 24),
                      )
                    else
                      Text(
                        '#${entry.rank}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                  ],
                ),
              ),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.userName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                              ),
                        ),
                        if (isCurrentUser)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.points}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'pts',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

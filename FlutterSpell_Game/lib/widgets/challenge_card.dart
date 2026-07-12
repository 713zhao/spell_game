import 'package:flutter/material.dart';
import '../models/game_models.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final String? currentUserName;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onView;

  const ChallengeCard({
    required this.challenge,
    this.currentUserName,
    this.onAccept,
    this.onComplete,
    this.onView,
  });

  String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool isCurrentUserChallenger() {
    return challenge.challengerName == currentUserName;
  }

  String getOpponentName() {
    if (isCurrentUserChallenger()) {
      return challenge.challengeeName ?? 'Unknown';
    } else {
      return challenge.challengerName ?? 'Unknown';
    }
  }

  String getChallengeText() {
    if (isCurrentUserChallenger()) {
      return 'You challenged ${challenge.challengeeName}';
    } else {
      return '${challenge.challengerName} challenged you';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = getChallengeText();
    final status = challenge.status.toLowerCase();

    return Card(
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Challenge text and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level ${challenge.levelId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(status),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      getStatusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Winner indicator if completed
              if (status == 'completed' && challenge.winnerId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Winner determined',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'pending' && !isCurrentUserChallenger())
                    ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                    )
                  else if (status == 'active' && onComplete != null)
                    ElevatedButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Complete'),
                    )
                  else if (status == 'completed')
                    ElevatedButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
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

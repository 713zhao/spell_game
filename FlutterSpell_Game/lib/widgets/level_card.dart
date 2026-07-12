import 'package:flutter/material.dart';
import '../models/game_models.dart';

class LevelCard extends StatelessWidget {
  final Level level;
  final VoidCallback onTap;
  final bool isLocked;

  const LevelCard({
    required this.level,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: isLocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                          'Level ${level.id}: ${level.name}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (level.description != null)
                          Text(level.description!),
                      ],
                    ),
                  ),
                  if (isLocked)
                    const Icon(Icons.lock, size: 32)
                  else
                    Row(
                      children: List.generate(3, (i) {
                        // Stars would go here based on progress
                        return const Icon(
                          Icons.star,
                          color: Colors.grey,
                          size: 20,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isLocked)
                ElevatedButton(
                  onPressed: onTap,
                  child: const Text('Play'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

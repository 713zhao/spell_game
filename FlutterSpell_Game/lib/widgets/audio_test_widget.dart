import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// Widget for testing audio functionality across platforms
class AudioTestWidget extends StatefulWidget {
  final VoidCallback? onTestComplete;

  const AudioTestWidget({
    Key? key,
    this.onTestComplete,
  }) : super(key: key);

  @override
  State<AudioTestWidget> createState() => _AudioTestWidgetState();
}

class _AudioTestWidgetState extends State<AudioTestWidget> {
  late SoundService _soundService;
  Map<String, bool> _soundTests = {
    'correct_answer': false,
    'incorrect_answer': false,
    'level_complete': false,
    'streak_milestone': false,
    'cosmetic_unlock': false,
    'point_redemption': false,
    'pop': false,
  };

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
  }

  Future<void> _testSound(String soundName) async {
    try {
      switch (soundName) {
        case 'correct_answer':
          await _soundService.playCorrectAnswer();
          break;
        case 'incorrect_answer':
          await _soundService.playIncorrectAnswer();
          break;
        case 'level_complete':
          await _soundService.playLevelComplete();
          break;
        case 'streak_milestone':
          await _soundService.playStreakMilestone();
          break;
        case 'cosmetic_unlock':
          await _soundService.playCosmeticUnlock();
          break;
        case 'point_redemption':
          await _soundService.playPointRedemption();
          break;
        case 'pop':
          await _soundService.playPop();
          break;
      }

      setState(() {
        _soundTests[soundName] = true;
      });

      // Reset after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _soundTests[soundName] = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing $soundName: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Test'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sound Effect Tests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Click each button to test the corresponding sound effect. '
              'Make sure your device volume is turned up.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: _soundTests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final soundName = _soundTests.keys.elementAt(index);
                  final isPlaying = _soundTests[soundName] ?? false;

                  return ElevatedButton.icon(
                    onPressed: isPlaying ? null : () => _testSound(soundName),
                    icon: isPlaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.volume_up),
                    label: Text(
                      soundName.replaceAll('_', ' ').toUpperCase(),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: isPlaying ? Colors.blue[300] : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onTestComplete?.call();
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

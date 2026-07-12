import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class ReviewCaveScreen extends StatelessWidget {
  const ReviewCaveScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Review Cave', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro text
              Text(
                'Choose a practice mode to strengthen your skills!',
                style: DuolingoTextStyles.body.copyWith(
                  color: DuolingoColors.bodyText,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),

              // Mode 1: Weak Words Dojo
              _PracticeModeCard(
                icon: '🥋',
                title: 'Weak Words Dojo',
                description: 'Practice words with <80% accuracy',
                wordCount: 5,
                onStart: () => _onStartMode(context, 'Weak Words Dojo'),
              ),
              SizedBox(height: DuolingoSpacing.lg),

              // Mode 2: Speed Challenge
              _PracticeModeCard(
                icon: '⚡',
                title: 'Speed Challenge',
                description: '10 words in 60 seconds',
                wordCount: null,
                onStart: () => _onStartMode(context, 'Speed Challenge'),
              ),
              SizedBox(height: DuolingoSpacing.lg),

              // Mode 3: Perfect Score
              _PracticeModeCard(
                icon: '⭐',
                title: 'Perfect Score',
                description: 'Get 10/10 correct in a row',
                wordCount: null,
                onStart: () => _onStartMode(context, 'Perfect Score'),
              ),
              SizedBox(height: DuolingoSpacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        backgroundColor: DuolingoColors.backgroundWhite,
        selectedItemColor: DuolingoColors.primaryGreen,
        unselectedItemColor: DuolingoColors.neutralGray,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World Map'),
          BottomNavigationBarItem(icon: Icon(Icons.backpack), label: 'Backpack'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).pushReplacementNamed('/');
              break;
            case 1:
              Navigator.of(context).pushReplacementNamed('/world-map');
              break;
            case 2:
              Navigator.of(context).pushReplacementNamed('/backpack');
              break;
            case 3:
              Navigator.of(context).pushReplacementNamed('/progress');
              break;
            case 4:
              Navigator.of(context).pushReplacementNamed('/profile');
              break;
          }
        },
      ),
    );
  }

  void _onStartMode(BuildContext context, String modeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting $modeName...')),
    );
    // TODO: Navigate to practice screen with selected mode
  }
}

class _PracticeModeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final int? wordCount;
  final VoidCallback onStart;

  const _PracticeModeCard({
    required this.icon,
    required this.title,
    required this.description,
    this.wordCount,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DuolingoColors.backgroundWhite,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(
          color: DuolingoColors.reviewCaveGradient[0].withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: DuolingoShadows.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(DuolingoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon and Title
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 32)),
                SizedBox(width: DuolingoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: DuolingoTextStyles.cardTitle),
                      SizedBox(height: DuolingoSpacing.xs),
                      Text(
                        description,
                        style: DuolingoTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: DuolingoSpacing.md),

            // Word count badge (if available)
            if (wordCount != null)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.md,
                  vertical: DuolingoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DuolingoColors.reviewCaveGradient[0].withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusBadge),
                ),
                child: Text(
                  '$wordCount words to practice',
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.darkText,
                  ),
                ),
              ),

            SizedBox(height: DuolingoSpacing.md),

            // Start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Text('▶', style: TextStyle(fontSize: 14)),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DuolingoColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

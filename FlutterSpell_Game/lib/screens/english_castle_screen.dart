import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class EnglishCastleScreen extends StatefulWidget {
  const EnglishCastleScreen({Key? key}) : super(key: key);

  @override
  State<EnglishCastleScreen> createState() => _EnglishCastleScreenState();
}

class _EnglishCastleScreenState extends State<EnglishCastleScreen> {
  // Mock stage data
  final List<StageData> stages = [
    StageData(
      stageNumber: 1,
      title: 'Week 1: Vowels',
      progress: 1.0,
      stars: 3,
      isLocked: false,
    ),
    StageData(
      stageNumber: 2,
      title: 'Week 2: Consonants',
      progress: 0.66,
      stars: 2,
      isLocked: false,
    ),
    StageData(
      stageNumber: 3,
      title: 'Week 3: Blends',
      progress: 0.33,
      stars: 1,
      isLocked: false,
    ),
    StageData(
      stageNumber: 4,
      title: 'Week 4: Digraphs',
      progress: 0.0,
      stars: 0,
      isLocked: true,
    ),
    StageData(
      stageNumber: 5,
      title: 'Week 5: Review',
      progress: 0.0,
      stars: 0,
      isLocked: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('English Kingdom', style: DuolingoTextStyles.pageTitle),
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
              // Header section
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: DuolingoColors.englishKingdomGradient,
                  ),
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Row(
                  children: [
                    Text(
                      '🏰',
                      style: TextStyle(fontSize: 40),
                    ),
                    SizedBox(width: DuolingoSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Greetings, Scholar!',
                            style: DuolingoTextStyles.sectionTitle,
                          ),
                          SizedBox(height: DuolingoSpacing.xs),
                          Text(
                            'Master the English language through stages',
                            style: DuolingoTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Stages list
              Text(
                'Stages',
                style: DuolingoTextStyles.sectionTitle,
              ),
              SizedBox(height: DuolingoSpacing.md),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stages.length,
                itemBuilder: (context, index) {
                  return _StageCard(
                    stage: stages[index],
                    onTap: () {
                      if (!stages[index].isLocked) {
                        Navigator.pushNamed(
                          context,
                          '/english-level',
                          arguments: stages[index].stageNumber,
                        );
                      }
                    },
                  );
                },
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
}

// Stage data model
class StageData {
  final int stageNumber;
  final String title;
  final double progress; // 0.0 to 1.0
  final int stars; // 0 to 3
  final bool isLocked;

  StageData({
    required this.stageNumber,
    required this.title,
    required this.progress,
    required this.stars,
    required this.isLocked,
  });
}

// Individual stage card widget
class _StageCard extends StatelessWidget {
  final StageData stage;
  final VoidCallback onTap;

  const _StageCard({
    required this.stage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: stage.isLocked ? null : onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: DuolingoSpacing.md),
        padding: EdgeInsets.all(DuolingoSpacing.lg),
        decoration: BoxDecoration(
          color: stage.isLocked
              ? DuolingoColors.neutralGray
              : DuolingoColors.backgroundWhite,
          gradient: stage.isLocked
              ? null
              : LinearGradient(
                  colors: DuolingoColors.levelCardGradient,
                ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          border: Border.all(
            color: stage.isLocked
                ? DuolingoColors.secondaryButtonGray
                : DuolingoColors.informationBlue.withOpacity(0.3),
          ),
          boxShadow: stage.isLocked ? [] : DuolingoShadows.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with stage number and stars
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stage.title,
                  style: DuolingoTextStyles.cardTitle.copyWith(
                    color: stage.isLocked
                        ? DuolingoColors.bodyText.withOpacity(0.5)
                        : DuolingoColors.darkText,
                  ),
                ),
                _StarRating(stars: stage.stars, isLocked: stage.isLocked),
              ],
            ),
            SizedBox(height: DuolingoSpacing.md),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: DuolingoTextStyles.label.copyWith(
                    color: stage.isLocked
                        ? DuolingoColors.bodyText.withOpacity(0.5)
                        : DuolingoColors.bodyText,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stage.progress,
                    minHeight: DuolingoSpacing.progressBarHeight,
                    backgroundColor:
                        stage.isLocked ? Colors.grey[300] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      stage.isLocked
                          ? Colors.grey[400]!
                          : DuolingoColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: DuolingoSpacing.md),
            // Action button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(stage.progress * 100).toStringAsFixed(0)}% Complete',
                  style: DuolingoTextStyles.body.copyWith(
                    color: stage.isLocked
                        ? DuolingoColors.bodyText.withOpacity(0.5)
                        : DuolingoColors.bodyText,
                  ),
                ),
                if (stage.isLocked)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DuolingoSpacing.md,
                      vertical: DuolingoSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: DuolingoColors.neutralGray,
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                    child: Text(
                      '🔒 Locked',
                      style: DuolingoTextStyles.label.copyWith(
                        color: DuolingoColors.bodyText.withOpacity(0.5),
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DuolingoColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: DuolingoSpacing.lg,
                        vertical: DuolingoSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            DuolingoSpacing.radiusButton),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Enter ▶',
                      style: DuolingoTextStyles.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Star rating widget
class _StarRating extends StatelessWidget {
  final int stars;
  final bool isLocked;

  const _StarRating({
    required this.stars,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(left: DuolingoSpacing.xs),
          child: Text(
            index < stars ? '⭐' : '☆',
            style: TextStyle(
              fontSize: DuolingoSpacing.starSize,
              color: isLocked ? Colors.grey : null,
            ),
          ),
        ),
      ),
    );
  }
}

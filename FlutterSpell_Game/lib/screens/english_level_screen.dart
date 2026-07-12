import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class EnglishLevelScreen extends StatefulWidget {
  final int stageNumber;

  const EnglishLevelScreen({
    Key? key,
    required this.stageNumber,
  }) : super(key: key);

  @override
  State<EnglishLevelScreen> createState() => _EnglishLevelScreenState();
}

class _EnglishLevelScreenState extends State<EnglishLevelScreen> {
  late LevelData levelData;

  @override
  void initState() {
    super.initState();
    levelData = _getLevelData(widget.stageNumber);
  }

  // Mock level data based on stage number
  LevelData _getLevelData(int stageNumber) {
    const Map<int, LevelData> levelMap = {
      1: LevelData(
        levelNumber: 1,
        stageName: 'Week 1: Vowels',
        description: 'Learn the basic vowel sounds in English',
        words: [
          'apple',
          'elephant',
          'ice',
          'orange',
          'umbrella',
          'ant',
          'elf',
          'ink',
          'owl',
          'up',
        ],
      ),
      2: LevelData(
        levelNumber: 2,
        stageName: 'Week 2: Consonants',
        description: 'Master the fundamental consonant sounds',
        words: [
          'ball',
          'cat',
          'dog',
          'fish',
          'goat',
          'house',
          'jump',
          'kite',
          'lion',
          'moon',
        ],
      ),
      3: LevelData(
        levelNumber: 3,
        stageName: 'Week 3: Blends',
        description: 'Practice consonant blends and combinations',
        words: [
          'black',
          'blue',
          'class',
          'clock',
          'cloud',
          'flag',
          'flow',
          'glass',
          'green',
          'plum',
        ],
      ),
      4: LevelData(
        levelNumber: 4,
        stageName: 'Week 4: Digraphs',
        description: 'Learn digraph combinations and their sounds',
        words: [
          'chair',
          'change',
          'cheap',
          'check',
          'chocolate',
          'church',
          'chef',
          'charge',
          'champ',
          'chase',
        ],
      ),
      5: LevelData(
        levelNumber: 5,
        stageName: 'Week 5: Review',
        description: 'Review everything you have learned',
        words: [
          'beautiful',
          'butterfly',
          'camera',
          'different',
          'elephant',
          'forest',
          'guitar',
          'history',
          'important',
          'interesting',
        ],
      ),
    };

    return levelMap[stageNumber] ??
        LevelData(
          levelNumber: stageNumber,
          stageName: 'Week $stageNumber',
          description: 'Practice stage $stageNumber',
          words: List.generate(
            10,
            (index) => 'word${index + 1}',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text(levelData.stageName, style: DuolingoTextStyles.pageTitle),
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
              // Level header card
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: DuolingoColors.englishKingdomGradient,
                  ),
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelData.stageName,
                      style: DuolingoTextStyles.pageTitle,
                    ),
                    SizedBox(height: DuolingoSpacing.md),
                    Text(
                      levelData.description,
                      style: DuolingoTextStyles.body,
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Words section header
              Text(
                'Words to Practice',
                style: DuolingoTextStyles.sectionTitle,
              ),
              SizedBox(height: DuolingoSpacing.md),
              // Words grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: levelData.words.length,
                itemBuilder: (context, index) {
                  return _WordCard(word: levelData.words[index]);
                },
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Start button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to practice screen or show practice modal
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Starting practice for ${levelData.stageName}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuolingoColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: DuolingoSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Start Practice ▶',
                    style: DuolingoTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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

// Level data model
class LevelData {
  final int levelNumber;
  final String stageName;
  final String description;
  final List<String> words;

  LevelData({
    required this.levelNumber,
    required this.stageName,
    required this.description,
    required this.words,
  });
}

// Individual word card widget
class _WordCard extends StatelessWidget {
  final String word;

  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DuolingoColors.backgroundWhite,
        gradient: LinearGradient(
          colors: DuolingoColors.levelCardGradient,
        ),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(
          color: DuolingoColors.informationBlue.withOpacity(0.3),
        ),
        boxShadow: DuolingoShadows.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word,
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.cardTitle.copyWith(
              fontSize: 15,
            ),
          ),
          SizedBox(height: DuolingoSpacing.sm),
          Icon(
            Icons.volume_up,
            color: DuolingoColors.informationBlue,
            size: DuolingoSpacing.iconSize,
          ),
        ],
      ),
    );
  }
}

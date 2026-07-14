import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';
import 'lesson_overview_screen.dart';

/// SpellQuest Journey Selection (Duolingo-style winding path) for the
/// English Kingdom. Renders the shared [JourneyPath] widget over this
/// kingdom's stage data.
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
        isLocked: false),
    StageData(
        stageNumber: 2,
        title: 'Week 2: Consonants',
        progress: 0.66,
        stars: 2,
        isLocked: false),
    StageData(
        stageNumber: 3,
        title: 'Week 3: Blends',
        progress: 0.33,
        stars: 1,
        isLocked: false),
    StageData(
        stageNumber: 4,
        title: 'Week 4: Digraphs',
        progress: 0.0,
        stars: 0,
        isLocked: true),
    StageData(
        stageNumber: 5,
        title: 'Week 5: Review',
        progress: 0.0,
        stars: 0,
        isLocked: true),
  ];

  bool _allowSkipLock = true;

  @override
  void initState() {
    super.initState();
    _loadParentMode();
  }

  Future<void> _loadParentMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _allowSkipLock = !(prefs.getBool('parent_mode') ?? false));
  }

  void _openLesson(int stageNumber) {
    Navigator.pushNamed(
      context,
      '/lesson-overview',
      arguments: LessonOverviewArgs(
        levelId: stageNumber,
        kingdom: KingdomTheme.english,
      ),
    );
  }

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
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: DuolingoColors.englishKingdomGradient,
                  ),
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Row(
                  children: [
                    const Text('🏰', style: TextStyle(fontSize: 40)),
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
              JourneyPath(
                stages: stages,
                kingdomEmoji: '🏰',
                kingdomLabel: 'Castle',
                gradientColors: DuolingoColors.englishKingdomGradient,
                allowSkipLock: _allowSkipLock,
                onSelectLesson: _openLesson,
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
          BottomNavigationBarItem(
              icon: Icon(Icons.backpack), label: 'Backpack'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: 'Progress'),
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';
import '../main.dart' show gameProvider;
import 'lesson_overview_screen.dart';

/// SpellQuest Journey Selection (Duolingo-style winding path) for the
/// Chinese Kingdom. Same [JourneyPath] widget as English Kingdom, fed by
/// lessons from the backend's `/lessons/{user}?subject=CN` endpoint (each
/// lesson combines its ::read and ::write tag variants).
class ChineseKingdomScreen extends StatefulWidget {
  const ChineseKingdomScreen({Key? key}) : super(key: key);

  @override
  State<ChineseKingdomScreen> createState() => _ChineseKingdomScreenState();
}

class _ChineseKingdomScreenState extends State<ChineseKingdomScreen> {
  bool _allowSkipLock = true;

  @override
  void initState() {
    super.initState();
    _loadParentMode();
    gameProvider.addListener(_onChanged);
    gameProvider.loadLessons('CN');
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    gameProvider.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _loadParentMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _allowSkipLock = !(prefs.getBool('parent_mode') ?? false));
  }

  List<LessonSummary> get _lessons => gameProvider.chineseLessons;

  List<StageData> get _stages => [
        for (var i = 0; i < _lessons.length; i++)
          StageData(
            stageNumber: i + 1,
            title: _lessons[i].displayName,
            progress: _lessons[i].masteryPct,
            stars: _lessons[i].stars,
            isLocked: _lessons[i].status == 'locked',
            spellDate: _lessons[i].spellDate,
          ),
      ];

  void _openLesson(int stageNumber) {
    final lesson = _lessons[stageNumber - 1];
    Navigator.pushNamed(
      context,
      '/lesson-overview',
      arguments: LessonOverviewArgs(
        lesson: lesson,
        subject: 'CN',
        kingdom: KingdomTheme.chinese,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Chinese Kingdom', style: DuolingoTextStyles.pageTitle),
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
                    colors: DuolingoColors.chineseKingdomGradient,
                  ),
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Row(
                  children: [
                    const Text('🐉', style: TextStyle(fontSize: 40)),
                    SizedBox(width: DuolingoSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ni Hao, Traveler!',
                            style: DuolingoTextStyles.sectionTitle,
                          ),
                          SizedBox(height: DuolingoSpacing.xs),
                          Text(
                            'Journey through Forest, River, and Mountain',
                            style: DuolingoTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              if (_lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                JourneyPath(
                  stages: _stages,
                  kingdomEmoji: '🐉',
                  kingdomLabel: 'Kingdom',
                  gradientColors: DuolingoColors.chineseKingdomGradient,
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

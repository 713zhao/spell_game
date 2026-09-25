import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';
import 'package:spell_game/widgets/label_type_filter_bar.dart';
import 'package:spell_game/utils/last_lesson.dart';
import 'package:spell_game/utils/lesson_label_filter.dart';
import 'package:spell_game/utils/lesson_unlock_overrides.dart';
import 'package:spell_game/utils/treasure_claims.dart';
import 'package:spell_game/utils/practice_sessions.dart';
import 'package:spell_game/providers/game_provider.dart';
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
  static const String _subject = 'CN';

  bool _allowSkipLock = true;
  bool _loadingLessons = true;
  bool _autoHighlightHandled = false;
  String? _highlightLessonKey;
  String? _labelFilter; // null = All
  Set<String> _unlockedNodes = {};
  Set<int> _claimedMilestones = {};
  Map<String, int> _practiceSessionCounts = {};
  // The server-computed track for [_labelFilter] (each label type is its own
  // lock sequence); null until fetched, or while the filter is All.
  List<LessonSummary>? _typeLessons;
  int _seenLessonsVersion = 0;
  late GameProvider gameProvider;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();
    _loadParentMode();
    _loadUnlockedOverrides();
    _loadClaimedMilestones();
    _loadPracticeSessionCounts();
    gameProvider.addListener(_onChanged);
    _loadLessons();
  }

  Future<void> _loadUnlockedOverrides() async {
    final unlocked = await getUnlockedNodes(_subject);
    if (!mounted) return;
    setState(() => _unlockedNodes = unlocked);
  }

  Future<void> _loadClaimedMilestones() async {
    final claimed = await getClaimedTreasures(_subject);
    if (!mounted) return;
    setState(() => _claimedMilestones = claimed);
  }

  Future<void> _loadPracticeSessionCounts() async {
    final counts = await getPracticeSessionCounts(_subject);
    if (!mounted) return;
    setState(() => _practiceSessionCounts = counts);
  }

  Future<void> _handleMilestoneClaimed(int index) async {
    await addClaimedTreasure(_subject, index);
    if (!mounted) return;
    setState(() => _claimedMilestones = {..._claimedMilestones, index});
  }

  Future<void> _handleUnlockConfirmed(
    int stageNumber,
    int checkpointIndex,
  ) async {
    final lessonKey = _lessons[stageNumber - 1].lessonKey;
    await addUnlockedNode(_subject, lessonKey, checkpointIndex);
    if (!mounted) return;
    setState(
      () => _unlockedNodes = {..._unlockedNodes, '$lessonKey#$checkpointIndex'},
    );
  }

  Future<void> _loadLessons() async {
    _labelFilter = await getLabelFilter(_subject);
    await gameProvider.loadLessons(_subject);
    _seenLessonsVersion = gameProvider.lessonsVersion;
    // A saved filter for a type that no longer exists means All.
    if (_labelFilter != null &&
        !labelTypesOf(_allLessons).contains(_labelFilter)) {
      _labelFilter = null;
    }
    await _refreshTypeLessons();
    if (!mounted) return;
    setState(() => _loadingLessons = false);
    await _maybeHighlightDefaultLesson();
  }

  Future<void> _maybeHighlightDefaultLesson() async {
    if (_autoHighlightHandled || _lessons.isEmpty) return;
    _autoHighlightHandled = true;
    final target = await resolveDefaultLesson(
      context: context,
      lessons: _lessons,
      subject: _subject,
    );
    if (target != null && mounted) {
      setState(() => _highlightLessonKey = target.lessonKey);
    }
  }

  void _onChanged() {
    if (!mounted) return;
    // Lessons were reloaded (e.g. after a study session): the per-type
    // track is fetched separately, so refresh it too.
    if (gameProvider.lessonsVersion != _seenLessonsVersion) {
      _seenLessonsVersion = gameProvider.lessonsVersion;
      if (_labelFilter != null) _refreshTypeLessons();
      _loadPracticeSessionCounts();
    }
    setState(() {});
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

  List<LessonSummary> get _allLessons => gameProvider.chineseLessons;

  bool get _showingType => _labelFilter != null && _typeLessons != null;

  List<LessonSummary> get _lessons =>
      _showingType ? _typeLessons! : _allLessons;

  Future<void> _refreshTypeLessons() async {
    final filter = _labelFilter;
    if (filter == null) {
      _typeLessons = null;
      return;
    }
    final track = await gameProvider.fetchLessons(_subject, labelType: filter);
    if (!mounted || _labelFilter != filter) return;
    setState(() {
      _typeLessons = track;
      // Couldn't fetch the track: fall back to showing everything.
      if (track == null) _labelFilter = null;
    });
  }

  int? get _highlightStageNumber {
    final i = _lessons.indexWhere((l) => l.lessonKey == _highlightLessonKey);
    return i < 0 ? null : i + 1;
  }

  Future<void> _onFilterSelected(String? labelType) async {
    setState(() {
      _labelFilter = labelType;
      _typeLessons = null;
    });
    setLabelFilter(_subject, labelType);
    await _refreshTypeLessons();
  }

  List<StageData> get _stages {
    final showBadge = labelTypesOf(_allLessons).length > 1;
    return [
      for (var i = 0; i < _lessons.length; i++)
        StageData(
          stageNumber: i + 1,
          title: _lessons[i].displayName,
          progress: _lessons[i].masteryPct,
          stars: _lessons[i].stars,
          isLocked: _lessons[i].status == 'locked',
          isCompleted: _lessons[i].status == 'completed',
          spellDate: _lessons[i].spellDate,
          checkpointIndex: _lessons[i].checkpointIndex,
          checkpointCount: _lessons[i].checkpointCount,
          checkpointPassed: [for (final c in _lessons[i].checkpoints) c.passed],
          reviewPassed: _lessons[i].reviewPassed,
          reviewDueCount: _lessons[i].reviewDueCount,
          unlockedNodes: unlockedIndicesFor(
            _unlockedNodes,
            _lessons[i].lessonKey,
          ),
          labelBadge: showBadge ? labelTypeEmoji(_lessons[i].labelType) : null,
          practiceSessionsDone:
              _practiceSessionCounts[_lessons[i].lessonKey] ?? 0,
        ),
    ];
  }

  Future<void> _openLesson(int stageNumber, int? checkpointIndex) async {
    final lesson = _lessons[stageNumber - 1];
    await setLastLessonKey(_subject, lesson.lessonKey);
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/lesson-overview',
      arguments: LessonOverviewArgs(
        lesson: lesson,
        subject: _subject,
        checkpoint: checkpointIndex,
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
        actions: const [AccountAvatarButton()],
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
                  borderRadius: BorderRadius.circular(
                    DuolingoSpacing.radiusCard,
                  ),
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
              if (!_loadingLessons)
                LabelTypeFilterBar(
                  types: labelTypesOf(_allLessons),
                  selected: _labelFilter,
                  onSelected: _onFilterSelected,
                ),
              if (!_loadingLessons && labelTypesOf(_allLessons).length > 1)
                SizedBox(height: DuolingoSpacing.lg),
              if (_loadingLessons || (_labelFilter != null && !_showingType))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_lessons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No lessons assigned yet.\nCheck back soon!',
                      textAlign: TextAlign.center,
                      style: DuolingoTextStyles.body,
                    ),
                  ),
                )
              else
                JourneyPath(
                  stages: _stages,
                  kingdomEmoji: '🐉',
                  kingdomLabel: 'Kingdom',
                  gradientColors: DuolingoColors.chineseKingdomGradient,
                  allowSkipLock: _allowSkipLock,
                  onSelectNode: _openLesson,
                  onUnlockConfirmed: _handleUnlockConfirmed,
                  highlightStageNumber: _highlightStageNumber,
                  claimedMilestones: _claimedMilestones,
                  onMilestoneClaimed: _handleMilestoneClaimed,
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
        unselectedItemColor: DuolingoColors.navInactiveGray,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Backpack',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
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

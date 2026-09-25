import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/moe_word_models.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/services/sound_service.dart';
import 'package:spell_game/widgets/hanzi_writer_trace.dart';
import 'package:spell_game/widgets/moe_flip_card.dart';

enum _MoeFilter { all, recognise, write, difficult }

/// A character paired with the lesson it belongs to, used once lessons are
/// flattened into a single browsable deck.
class _DeckEntry {
  final MoeCharacter character;
  final MoeLesson lesson;

  _DeckEntry({required this.character, required this.lesson});
}

/// "Chinese Word Cards" - flip-card browsing of the official MOE Primary 1
/// Chinese character list (modeled on https://chinese.getbuzzi.com): a grade
/// + lesson selection (via a settings sheet), a flattened, filterable deck
/// of characters, a known/remaining progress bar, and per-character flip
/// cards showing pinyin/meaning/audio on the back plus a practiced-count
/// badge, a difficulty star, and a "Practice writing" button that reuses the
/// same HanziWriter trace and StudyHistory counter as the main study flow.
class MoeWordCardsScreen extends StatefulWidget {
  const MoeWordCardsScreen({super.key});

  @override
  State<MoeWordCardsScreen> createState() => _MoeWordCardsScreenState();
}

class _MoeWordCardsScreenState extends State<MoeWordCardsScreen> {
  static const _grades = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

  String _selectedGrade = 'P1';
  MoeWordCardsResult? _result;
  bool _loading = true;
  String? _error;
  int _cardIndex = 0;
  _MoeFilter _filter = _MoeFilter.all;
  Set<String> _selectedLessonKeys = {};
  Set<int> _difficultIds = {};
  SharedPreferences? _prefs;
  final SoundService _soundService = SoundService();

  // "Anki mode": SRS-ordered, backend-scoped deck instead of a flat browse
  // of every character in the selected lessons. Persisted locally
  // (SharedPreferences) since it's a per-device study preference; the
  // daily word count it uses is the real backend UserSetting.num_study_words
  // (shared with the main study flow), fetched/updated via the settings API.
  bool _ankiMode = true;
  int _numStudyWords = 10;
  bool _ankiDeckLoading = false;
  List<_DeckEntry> _ankiDeck = [];
  int _ankiSessionReviewed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gameProvider = context.read<GameProvider>();
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final result = await gameProvider.apiClient.getMoeWords(
        grade: _selectedGrade,
      );
      int numStudyWords = _numStudyWords;
      try {
        final settings = await gameProvider.apiClient.getUserSettings();
        numStudyWords =
            (settings['num_study_words'] as num?)?.toInt() ?? numStudyWords;
      } catch (_) {
        // Keep the last-known/default count - the settings sheet's stepper
        // still works locally and will retry the save on next change.
      }
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _result = result;
        // Default: all lessons for this grade are selected.
        _selectedLessonKeys = result.lessons.map((l) => l.lessonKey).toSet();
        _difficultIds = _loadDifficultIds(prefs, _selectedGrade);
        _filter = _MoeFilter.all;
        _cardIndex = 0;
        _ankiMode = prefs.getBool(_ankiModePrefsKey) ?? true;
        _numStudyWords = numStudyWords;
        _loading = false;
      });
      if (_ankiMode) {
        await _loadAnkiDeck();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static const String _ankiModePrefsKey = 'moe_anki_mode';

  String _difficultPrefsKey(String grade) => 'moe_difficult_$grade';

  Set<int> _loadDifficultIds(SharedPreferences prefs, String grade) {
    final stored = prefs.getStringList(_difficultPrefsKey(grade)) ?? [];
    return stored.map(int.parse).toSet();
  }

  Future<void> _saveDifficultIds() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList(
      _difficultPrefsKey(_selectedGrade),
      _difficultIds.map((id) => id.toString()).toList(),
    );
  }

  void _toggleDifficult(int characterId) {
    setState(() {
      if (_difficultIds.contains(characterId)) {
        _difficultIds.remove(characterId);
      } else {
        _difficultIds.add(characterId);
      }
      _cardIndex = _cardIndex.clamp(
        0,
        _filteredDeck.isEmpty ? 0 : _filteredDeck.length - 1,
      );
    });
    _saveDifficultIds();
  }

  /// Every currently-loaded character keyed by id, paired with its lesson -
  /// used to enrich the backend's SRS-ordered `/deck` response (which only
  /// has word_id/text/state) back into the `MoeCharacter`/`MoeLesson` shape
  /// the rest of this screen (and the filter pills) already rely on.
  Map<int, _DeckEntry> get _charById {
    final result = _result;
    final map = <int, _DeckEntry>{};
    if (result == null) return map;
    for (final lesson in result.lessons) {
      for (final character in lesson.characters) {
        map[character.id] = _DeckEntry(character: character, lesson: lesson);
      }
    }
    return map;
  }

  /// Fetches the SRS-ordered deck for the selected lessons (tag-scoped,
  /// limited to [_numStudyWords]) and enriches each backend card back into
  /// a `_DeckEntry` using [_charById], preserving the backend's due-first
  /// ordering.
  Future<void> _loadAnkiDeck() async {
    if (_selectedLessonKeys.isEmpty) return;
    setState(() => _ankiDeckLoading = true);
    try {
      final gameProvider = context.read<GameProvider>();
      final cards = await gameProvider.apiClient.getDeckCards(
        tags: _selectedLessonKeys.toList(),
        limit: _numStudyWords,
      );
      if (!mounted) return;
      final lookup = _charById;
      final entries = <_DeckEntry>[];
      for (final card in cards) {
        final entry = lookup[card.word.id];
        if (entry != null) entries.add(entry);
      }
      setState(() {
        _ankiDeck = entries;
        _ankiDeckLoading = false;
        _cardIndex = 0;
        _ankiSessionReviewed = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ankiDeck = [];
        _ankiDeckLoading = false;
      });
    }
  }

  Future<void> _setAnkiMode(bool value) async {
    setState(() {
      _ankiMode = value;
      _cardIndex = 0;
    });
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_ankiModePrefsKey, value);
    if (value) {
      await _loadAnkiDeck();
    }
  }

  /// Persists a new daily word count both locally and to the real backend
  /// UserSetting (shared with the main study flow), then - if Anki mode is
  /// on - refetches the deck at the new size.
  Future<void> _adjustNumStudyWords(int delta) async {
    final next = (_numStudyWords + delta).clamp(1, 50);
    if (next == _numStudyWords) return;
    setState(() => _numStudyWords = next);
    try {
      final gameProvider = context.read<GameProvider>();
      await gameProvider.apiClient.updateUserSettings(numStudyWords: next);
    } catch (_) {
      // Best-effort - the local value still drives this session's deck size
      // and the next successful save will reconcile the backend.
    }
    if (_ankiMode) {
      await _loadAnkiDeck();
    }
  }

  /// Bumps a character's practiced-count badge locally (mirroring what a
  /// backend refetch would show) in both the whole-grade [_result] (read by
  /// browse mode) and [_ankiDeck] (read by Anki mode, which doesn't rebuild
  /// its entries from [_result]).
  void _bumpPracticedCount(int characterId) {
    final result = _result;
    if (result != null) {
      final updatedLessons = result.lessons.map((lesson) {
        final updatedChars = lesson.characters
            .map(
              (c) => c.id == characterId
                  ? c.copyWith(practicedCount: c.practicedCount + 1)
                  : c,
            )
            .toList();
        return MoeLesson(
          lessonKey: lesson.lessonKey,
          term: lesson.term,
          displayName: lesson.displayName,
          characters: updatedChars,
        );
      }).toList();
      _result = MoeWordCardsResult(
        grade: result.grade,
        supported: result.supported,
        lessons: updatedLessons,
      );
    }
    _ankiDeck = _ankiDeck
        .map(
          (e) => e.character.id == characterId
              ? _DeckEntry(
                  character: e.character.copyWith(
                    practicedCount: e.character.practicedCount + 1,
                  ),
                  lesson: e.lesson,
                )
              : e,
        )
        .toList();
  }

  /// Handles an Again/Hard/Good/Easy tap from the card back in Anki mode:
  /// submits the SM-2 quality to the backend, bumps the practiced-count
  /// badge, then advances to the next card (real Anki UX - immediate
  /// advance, no confirmation step).
  Future<void> _rate(MoeCharacter character, int quality) async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.submitReview(character.id, quality);
    if (!mounted) return;
    setState(() {
      _ankiSessionReviewed++;
      _bumpPracticedCount(character.id);
      final deck = _filteredDeck;
      if (deck.isEmpty) {
        _cardIndex = 0;
      } else if (_cardIndex < deck.length - 1) {
        _cardIndex++;
      } else {
        _cardIndex = deck.length - 1;
      }
    });
  }

  /// Switches grade and reloads. Returns the in-flight [_load] future so
  /// callers (the settings sheet's grade selector) can wait for the new
  /// grade's lessons to actually arrive before refreshing sheet-local state
  /// that was otherwise captured as a stale snapshot from when the sheet
  /// was first opened.
  Future<void> _selectGrade(String grade) {
    if (grade == _selectedGrade) return Future.value();
    setState(() => _selectedGrade = grade);
    return _load();
  }

  void _playAudio(String text) {
    _soundService.playWordPronunciation(text);
  }

  /// All characters from the currently-selected lessons, flattened into one
  /// ordered deck (each entry keeps a reference to its parent lesson).
  List<_DeckEntry> get _flattenedDeck {
    if (_ankiMode) return _ankiDeck;
    final result = _result;
    if (result == null) return [];
    final entries = <_DeckEntry>[];
    for (final lesson in result.lessons) {
      if (!_selectedLessonKeys.contains(lesson.lessonKey)) continue;
      for (final character in lesson.characters) {
        entries.add(_DeckEntry(character: character, lesson: lesson));
      }
    }
    return entries;
  }

  /// The flattened deck further narrowed by the active filter pill.
  List<_DeckEntry> get _filteredDeck {
    final deck = _flattenedDeck;
    switch (_filter) {
      case _MoeFilter.all:
        return deck;
      case _MoeFilter.recognise:
        return deck.where((e) => !e.character.writeRequired).toList();
      case _MoeFilter.write:
        return deck.where((e) => e.character.writeRequired).toList();
      case _MoeFilter.difficult:
        return deck
            .where((e) => _difficultIds.contains(e.character.id))
            .toList();
    }
  }

  void _selectFilter(_MoeFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _cardIndex = 0;
    });
  }

  /// Opens the same guided handwriting trace used in the main study flow
  /// for this character, and on completion submits a review to the
  /// backend so StudyHistory.count - and therefore this card's "practiced
  /// N times" badge - actually increments.
  ///
  /// Uses a fixed-size, non-scrollable dialog (not a draggable bottom
  /// sheet) so a touch-drag on the tracing canvas can never be
  /// misinterpreted as a sheet-drag gesture and close the window mid-stroke.
  /// `barrierDismissible: true` still lets the user tap outside to dismiss.
  Future<void> _practiceWriting(MoeCharacter character) async {
    final controller = HanziWriterTraceController();
    var completed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          ),
          backgroundColor: Colors.white,
          child: Container(
            width: 300,
            height: 420,
            padding: EdgeInsets.all(DuolingoSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trace ${character.text}',
                  style: DuolingoTextStyles.sectionTitle,
                ),
                SizedBox(height: DuolingoSpacing.lg),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: HanziWriterTrace(
                    character: character.text,
                    size: 220,
                    controller: controller,
                    onComplete: () {
                      completed = true;
                      _soundService.playCorrectAnswer();
                      if (Navigator.of(dialogContext).canPop()) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    onUnavailable: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Handwriting trace isn\'t available for this character on this device.',
                          ),
                        ),
                      );
                      if (Navigator.of(dialogContext).canPop()) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ),
                SizedBox(height: DuolingoSpacing.md),
                TextButton(
                  onPressed: () => controller.showStrokeOrder(),
                  child: Text(
                    'Show me ✍️',
                    style: DuolingoTextStyles.label.copyWith(
                      color: DuolingoColors.informationBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!completed || !mounted) return;

    final gameProvider = context.read<GameProvider>();
    await gameProvider.submitReview(character.id, 5);
    if (!mounted) return;

    // Bump the badge locally without a full reload.
    setState(() {
      if (_ankiMode) _ankiSessionReviewed++;
      _bumpPracticedCount(character.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Chinese Word Cards', style: DuolingoTextStyles.pageTitle),
        centerTitle: true,
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Grade and lessons',
            onPressed: _result == null ? null : _openSettingsSheet,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    final result = _result;
    if (result == null || !result.supported || result.lessons.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.xl),
          child: Text(
            result != null && !result.supported
                ? '$_selectedGrade word cards are coming soon!'
                : 'No word cards available yet.',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.body,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(height: DuolingoSpacing.md),
        _buildSummaryCard(result),
        SizedBox(height: DuolingoSpacing.md),
        _buildFilterPills(),
        SizedBox(height: DuolingoSpacing.sm),
        _buildProgressRow(),
        SizedBox(height: DuolingoSpacing.md),
        Expanded(child: _buildCardCarousel()),
      ],
    );
  }

  Widget _buildSummaryCard(MoeWordCardsResult result) {
    final allSelected = _selectedLessonKeys.length == result.lessons.length;
    final lessonSummary = allSelected
        ? 'All Lessons'
        : '${_selectedLessonKeys.length} lesson${_selectedLessonKeys.length == 1 ? '' : 's'} selected';
    final total = _filteredDeck.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: DuolingoSpacing.md,
          vertical: DuolingoSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: DuolingoColors.wordCardsGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        ),
        child: Text(
          '${_gradeDisplayName(_selectedGrade)} - $lessonSummary - $total card${total == 1 ? '' : 's'} in total',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.cardTitle,
        ),
      ),
    );
  }

  String _gradeDisplayName(String grade) {
    switch (grade) {
      case 'P1':
        return 'Primary 1';
      case 'P2':
        return 'Primary 2';
      case 'P3':
        return 'Primary 3';
      case 'P4':
        return 'Primary 4';
      case 'P5':
        return 'Primary 5';
      case 'P6':
        return 'Primary 6';
      default:
        return grade;
    }
  }

  Widget _buildFilterPills() {
    final pills = [
      (_MoeFilter.all, 'All Types'),
      (_MoeFilter.recognise, '识读字 Recognise'),
      (_MoeFilter.write, '识写字 Write'),
      (_MoeFilter.difficult, '⭐ Difficult'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
        itemCount: pills.length,
        itemBuilder: (context, index) {
          final (filter, label) = pills[index];
          final selected = filter == _filter;
          return Padding(
            padding: EdgeInsets.only(right: DuolingoSpacing.sm),
            child: GestureDetector(
              onTap: () => _selectFilter(filter),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.md,
                  vertical: DuolingoSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? DuolingoColors.darkText
                      : DuolingoColors.neutralGray,
                  borderRadius: BorderRadius.circular(
                    DuolingoSpacing.radiusButton,
                  ),
                ),
                child: Text(
                  label,
                  style: DuolingoTextStyles.label.copyWith(
                    color: selected ? Colors.white : DuolingoColors.darkText,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressRow() {
    final deck = _filteredDeck;
    final total = deck.length;
    final int primary;
    final int secondary;
    final String primaryLabel;
    final String secondaryLabel;
    if (_ankiMode) {
      primary = _ankiSessionReviewed.clamp(0, total);
      secondary = (total - primary).clamp(0, total);
      primaryLabel = '🧠 $primary reviewed';
      secondaryLabel = '📋 $secondary left in session';
    } else {
      primary = deck.where((e) => e.character.practicedCount > 0).length;
      secondary = total - primary;
      primaryLabel = '✅ $primary known';
      secondaryLabel = '🔖 $secondary left';
    }
    final percent = total == 0 ? 0 : ((primary / total) * 100).round();
    final fraction = total == 0 ? 0.0 : primary / total;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                primaryLabel,
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.bodyText,
                ),
              ),
              Text(
                '$percent%',
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                secondaryLabel,
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.bodyText,
                ),
              ),
            ],
          ),
          SizedBox(height: DuolingoSpacing.xs),
          Container(
            width: double.infinity,
            height: DuolingoSpacing.progressBarHeight,
            decoration: BoxDecoration(
              color: DuolingoColors.neutralGray,
              borderRadius: BorderRadius.circular(DuolingoSpacing.radiusBadge),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: DuolingoColors.primaryGreen,
                  borderRadius: BorderRadius.circular(
                    DuolingoSpacing.radiusBadge,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardCarousel() {
    if (_ankiMode && _ankiDeckLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final deck = _filteredDeck;
    if (deck.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.xl),
          child: Text(
            'No cards match this filter yet.',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.body,
          ),
        ),
      );
    }
    final index = _cardIndex.clamp(0, deck.length - 1);
    final entry = deck[index];
    final character = entry.character;

    // The card's own content is now centered internally (MoeFlipCard sets
    // Stack alignment: Alignment.center), so the earlier off-center bug is
    // gone and the arrows can safely flank the card directly in a Row -
    // which also puts them right next to the card for easy pressing.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${entry.lesson.term} ${entry.lesson.displayName}',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.specialPurple,
            ),
          ),
          SizedBox(height: DuolingoSpacing.xs),
          Text(
            '${index + 1} / ${deck.length}',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
            ),
          ),
          SizedBox(height: DuolingoSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: index > 0
                    ? () => setState(() => _cardIndex = index - 1)
                    : null,
              ),
              SizedBox(width: DuolingoSpacing.xs),
              MoeFlipCard(
                key: ValueKey(character.id),
                character: character,
                onPlayAudio: () => _playAudio(character.text),
                onPracticeWriting: () => _practiceWriting(character),
                isDifficult: _difficultIds.contains(character.id),
                onToggleDifficult: () => _toggleDifficult(character.id),
                showRatingButtons: _ankiMode,
                onRate: _ankiMode
                    ? (quality) => _rate(character, quality)
                    : null,
              ),
              SizedBox(width: DuolingoSpacing.xs),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: index < deck.length - 1
                    ? () => setState(() => _cardIndex = index + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSettingsSheet() {
    final result = _result;
    if (result == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(DuolingoSpacing.lg),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Grade', style: DuolingoTextStyles.sectionTitle),
                    SizedBox(height: DuolingoSpacing.sm),
                    _buildGradeSelector(setSheetState),
                    SizedBox(height: DuolingoSpacing.lg),
                    Text('Lessons', style: DuolingoTextStyles.sectionTitle),
                    SizedBox(height: DuolingoSpacing.sm),
                    _buildLessonChecklist(setSheetState),
                    SizedBox(height: DuolingoSpacing.lg),
                    Text('Study mode', style: DuolingoTextStyles.sectionTitle),
                    SizedBox(height: DuolingoSpacing.sm),
                    _buildAnkiModeToggle(setSheetState),
                    SizedBox(height: DuolingoSpacing.sm),
                    _buildDailyWordCountRow(setSheetState),
                    SizedBox(height: DuolingoSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DuolingoColors.primaryGreen,
                          padding: EdgeInsets.symmetric(
                            vertical: DuolingoSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DuolingoSpacing.radiusButton,
                            ),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _cardIndex = 0);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(
                          'Done',
                          style: DuolingoTextStyles.label.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGradeSelector(void Function(void Function()) setSheetState) {
    return Row(
      children: _grades.map((grade) {
        final selected = grade == _selectedGrade;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.xs),
            child: GestureDetector(
              onTap: () {
                // _selectGrade runs synchronously up to its first `await`,
                // so _selectedGrade (and _loading) are already updated by
                // the time this setSheetState fires - the grade pill
                // highlights immediately. The lesson checklist below reads
                // live state (not a stale snapshot), so it refreshes once
                // the new grade's lessons actually arrive.
                final loadFuture = _selectGrade(grade);
                setSheetState(() {});
                loadFuture.then((_) {
                  if (mounted) setSheetState(() {});
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.sm),
                decoration: BoxDecoration(
                  color: selected
                      ? DuolingoColors.specialPurple
                      : DuolingoColors.neutralGray,
                  borderRadius: BorderRadius.circular(
                    DuolingoSpacing.radiusButton,
                  ),
                ),
                child: Text(
                  grade,
                  textAlign: TextAlign.center,
                  style: DuolingoTextStyles.cardTitle.copyWith(
                    color: selected ? Colors.white : DuolingoColors.darkText,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnkiModeToggle(void Function(void Function()) setSheetState) {
    return Container(
      padding: EdgeInsets.all(DuolingoSpacing.md),
      decoration: BoxDecoration(
        color: DuolingoColors.neutralGray,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🧠 Anki memory mode',
                  style: DuolingoTextStyles.cardTitle,
                ),
                SizedBox(height: 2),
                Text(
                  _ankiMode
                      ? 'Cards are ordered by what you\'re due to review, using spaced repetition.'
                      : 'Browse in lesson order.',
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.bodyText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _ankiMode,
            activeColor: DuolingoColors.primaryGreen,
            onChanged: (value) {
              setSheetState(() {});
              _setAnkiMode(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyWordCountRow(void Function(void Function()) setSheetState) {
    return Opacity(
      opacity: _ankiMode ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !_ankiMode,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Daily study words',
                style: DuolingoTextStyles.body,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                setSheetState(() {});
                _adjustNumStudyWords(-1);
              },
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$_numStudyWords',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.cardTitle,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                setSheetState(() {});
                _adjustNumStudyWords(1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonChecklist(void Function(void Function()) setSheetState) {
    // Reads live state (not a snapshot captured when the sheet was opened)
    // so switching grades from within the sheet refreshes this list once
    // the new grade's lessons arrive - see _selectGrade/_buildGradeSelector.
    final result = _result;
    if (_loading || result == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final lessons = result.lessons;
    if (lessons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '$_selectedGrade word cards are coming soon!',
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.body,
        ),
      );
    }
    final allSelected = _selectedLessonKeys.length == lessons.length;

    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: allSelected,
          title: Text('Select All', style: DuolingoTextStyles.cardTitle),
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedLessonKeys = lessons.map((l) => l.lessonKey).toSet();
              } else {
                // Don't allow zero lessons selected - fall back to "all".
                _selectedLessonKeys = lessons.map((l) => l.lessonKey).toSet();
              }
              _cardIndex = 0;
            });
            setSheetState(() {});
            if (_ankiMode) _loadAnkiDeck();
          },
        ),
        const Divider(height: 1),
        ...lessons.map((lesson) {
          final checked = _selectedLessonKeys.contains(lesson.lessonKey);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: checked,
            title: Text(
              '${lesson.term} ${lesson.displayName}',
              style: DuolingoTextStyles.body,
            ),
            secondary: Text(
              '${lesson.characters.length}',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.bodyText,
              ),
            ),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedLessonKeys.add(lesson.lessonKey);
                } else if (_selectedLessonKeys.length > 1) {
                  // Block deselecting the last remaining lesson.
                  _selectedLessonKeys.remove(lesson.lessonKey);
                }
                _cardIndex = 0;
              });
              setSheetState(() {});
              if (_ankiMode) _loadAnkiDeck();
            },
          );
        }),
      ],
    );
  }
}

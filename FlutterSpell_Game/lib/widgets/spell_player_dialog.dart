import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../services/app_settings.dart';
import '../services/sound_service.dart';

/// Dictation player: reads a lesson's words aloud. Previous / Play / Next
/// read the current word; Auto walks through every remaining word. Each word
/// is read [AppSettings.dictationRepeat] times with
/// [AppSettings.dictationInterval] seconds between reads.
class SpellPlayerDialog extends StatefulWidget {
  final String title;
  final List<String> words;

  const SpellPlayerDialog({Key? key, required this.title, required this.words})
    : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> words,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SpellPlayerDialog(title: title, words: words),
    );
  }

  @override
  State<SpellPlayerDialog> createState() => _SpellPlayerDialogState();
}

class _SpellPlayerDialogState extends State<SpellPlayerDialog> {
  final SoundService _sound = SoundService();
  int _index = 0;
  int _readCount = 0; // which read of the current word is in progress
  bool _auto = false;
  bool _playing = false;
  bool _reveal = false;
  int _run = 0; // bumped to cancel whatever playback loop is in flight

  @override
  void initState() {
    super.initState();
    _sound.init();
  }

  @override
  void dispose() {
    _run++;
    _sound.stop();
    super.dispose();
  }

  bool _alive(int run) => mounted && run == _run;

  /// Reads the current word repeat times. Returns false when cancelled.
  Future<bool> _readCurrent(int run) async {
    final repeat = AppSettings.dictationRepeat.value;
    for (var i = 0; i < repeat; i++) {
      if (!_alive(run)) return false;
      setState(() => _readCount = i + 1);
      await _sound.playWordPronunciation(widget.words[_index]);
      if (!_alive(run)) return false;
      await Future.delayed(
        Duration(seconds: AppSettings.dictationInterval.value),
      );
    }
    return _alive(run);
  }

  Future<void> _playOnce() async {
    final run = ++_run;
    setState(() => _playing = true);
    await _readCurrent(run);
    if (_alive(run)) setState(() => _playing = false);
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.words.length) return;
    _run++;
    setState(() {
      _index = next;
      _reveal = false;
    });
    _playOnce();
  }

  Future<void> _toggleAuto() async {
    if (_auto) {
      _run++;
      _sound.stop();
      setState(() {
        _auto = false;
        _playing = false;
      });
      return;
    }
    final run = ++_run;
    setState(() {
      _auto = true;
      _playing = true;
    });
    while (_alive(run)) {
      if (!await _readCurrent(run)) return;
      if (_index + 1 >= widget.words.length) break;
      setState(() {
        _index++;
        _reveal = false;
      });
    }
    if (_alive(run)) {
      setState(() {
        _auto = false;
        _playing = false;
      });
    }
  }

  Widget _stepper(
    String label,
    ValueNotifier<int> value,
    int min,
    int max,
    void Function(int) onSet,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: value,
      builder: (context, v, _) => Row(
        children: [
          Expanded(child: Text(label, style: DuolingoTextStyles.label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _auto || v <= min ? null : () => onSet(v - 1),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$v',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.cardTitle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _auto || v >= max ? null : () => onSet(v + 1),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback? onTap, {bool big = false}) {
    final enabled = onTap != null;
    final size = big ? 72.0 : 56.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: enabled
              ? DuolingoColors.informationBlue
              : const Color(0xFFE5E5E5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0xFFAFAFAF),
          size: big ? 40 : 30,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.words.length;
    final manual = _auto ? null : true;
    return AlertDialog(
      title: Text('🔊 ${widget.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Word ${_index + 1} of $total'
              '${_playing ? '  •  reading $_readCount/${AppSettings.dictationRepeat.value}' : ''}',
              style: DuolingoTextStyles.label,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _reveal = !_reveal),
              child: Container(
                width: double.infinity,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DuolingoColors.neutralGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _reveal ? widget.words[_index] : 'Tap to show word',
                  style: _reveal
                      ? DuolingoTextStyles.cardTitle
                      : DuolingoTextStyles.label,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _roundButton(
                  Icons.skip_previous,
                  manual != null && _index > 0 ? () => _go(-1) : null,
                ),
                _roundButton(
                  Icons.play_arrow,
                  manual != null ? _playOnce : null,
                  big: true,
                ),
                _roundButton(
                  Icons.skip_next,
                  manual != null && _index + 1 < total ? () => _go(1) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto'),
              subtitle: const Text('Read all words one by one'),
              value: _auto,
              onChanged: (_) => _toggleAuto(),
            ),
            const Divider(),
            _stepper(
              'Repeat (times)',
              AppSettings.dictationRepeat,
              1,
              10,
              (v) => AppSettings.setDictation(repeat: v),
            ),
            _stepper(
              'Interval (seconds)',
              AppSettings.dictationInterval,
              1,
              30,
              (v) => AppSettings.setDictation(interval: v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

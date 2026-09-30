import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../widgets/app_bottom_nav.dart';

class _WordRow {
  final TextEditingController text;
  String language;
  _WordRow({String text = '', this.language = 'en'})
      : text = TextEditingController(text: text);
}

/// Parent Mode: add words by typing into a table or importing a file, then
/// submit them all under one label (tag).
class ParentAddWordsScreen extends StatefulWidget {
  const ParentAddWordsScreen({super.key});

  @override
  State<ParentAddWordsScreen> createState() => _ParentAddWordsScreenState();
}

class _ParentAddWordsScreenState extends State<ParentAddWordsScreen> {
  static const _languages = ['en', 'zh'];
  final _labelController = TextEditingController();
  final List<_WordRow> _rows = [_WordRow(), _WordRow(), _WordRow()];
  List<String> _existingLabels = [];
  bool _isPublic = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final r in _rows) {
      r.text.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLabels() async {
    try {
      final tags =
          await context.read<GameProvider>().apiClient.getAvailableTags();
      if (!mounted) return;
      setState(() {
        _existingLabels = tags
            .map((t) => (t['tag'] ?? t['name'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .toList()
          ..sort();
      });
    } catch (_) {
      // Suggestions are optional.
    }
  }

  static final _hasChinese = RegExp(r'[一-鿿]');

  /// Parses CSV/TXT content: one word per line, optionally `word,lang`
  /// (a header row like `word,language` is skipped).
  List<_WordRow> _parseImport(String content) {
    final rows = <_WordRow>[];
    for (final raw in const LineSplitter().convert(content)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'[,\t]')).map((p) => p.trim()).toList();
      var word = parts.first.replaceAll('"', '');
      if (word.isEmpty) continue;
      if (rows.isEmpty && word.toLowerCase() == 'word') continue;
      var lang = parts.length > 1 ? parts[1].toLowerCase() : '';
      if (!_languages.contains(lang)) {
        lang = _hasChinese.hasMatch(word) ? 'zh' : 'en';
      }
      rows.add(_WordRow(text: word, language: lang));
    }
    return rows;
  }

  Future<void> _importFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    final imported = _parseImport(utf8.decode(bytes, allowMalformed: true));
    if (!mounted) return;
    if (imported.isEmpty) {
      _snack('No words found in that file.');
      return;
    }
    setState(() {
      _rows.removeWhere((r) => r.text.text.trim().isEmpty);
      _rows.addAll(imported);
    });
    _snack('Imported ${imported.length} word(s). Review, then Submit.');
  }

  Future<void> _scanImage({required bool camera}) async {
    final picked = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Extracting words from image...')),
        ]),
      ),
    );
    List<String> words = [];
    String? error;
    try {
      words = await context
          .read<GameProvider>()
          .apiClient
          .extractWordsFromImage(await picked.readAsBytes(), picked.name);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (error != null) return _snack(error);
    if (words.isEmpty) return _snack('No words found in that image.');
    setState(() {
      _rows.removeWhere((r) => r.text.text.trim().isEmpty);
      for (final w in words) {
        _rows.add(_WordRow(
            text: w, language: _hasChinese.hasMatch(w) ? 'zh' : 'en'));
      }
    });
    _snack('Found ${words.length} word(s). Review and edit, then Submit.');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit() async {
    final label = _labelController.text.trim().toUpperCase();
    final words = _rows.where((r) => r.text.text.trim().isNotEmpty).toList();
    if (label.isEmpty) return _snack('Enter a label for these words.');
    if (words.isEmpty) return _snack('Add at least one word.');
    setState(() => _submitting = true);
    final api = context.read<GameProvider>().apiClient;
    final failed = <_WordRow>[];
    var ok = 0;
    for (final r in words) {
      var success = false;
      try {
        success = await api.createUserWord(r.text.text.trim(), r.language,
            tag: label, isPublic: _isPublic);
      } catch (_) {}
      success ? ok++ : failed.add(r);
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _rows
        ..clear()
        ..addAll(failed.isEmpty ? [_WordRow(), _WordRow(), _WordRow()] : failed);
    });
    _snack(failed.isEmpty
        ? 'Added $ok word(s) to $label.'
        : 'Added $ok, ${failed.length} failed (left in the table).');
    _loadLabels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Words')),
      bottomNavigationBar: const AppBottomNav(current: '/parent-words'),
      body: ListView(
        padding: EdgeInsets.all(DuolingoSpacing.md),
        children: [
          Autocomplete<String>(
            optionsBuilder: (v) => _existingLabels.where((l) =>
                l.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => _labelController.text = v,
            fieldViewBuilder: (context, controller, focus, _) {
              // Keep our controller in sync with the Autocomplete field.
              controller.addListener(() {
                if (_labelController.text != controller.text) {
                  _labelController.text = controller.text;
                }
              });
              return TextField(
                controller: controller,
                focusNode: focus,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g. SMSP::P3::EN::TERM1)',
                  helperText: 'Pick an existing label or type a new one',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share label with everyone'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          Text('Words', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _scanImage(camera: false),
                icon: const Icon(Icons.image),
                label: const Text('Upload photo'),
              ),
              OutlinedButton.icon(
                onPressed: () => _scanImage(camera: true),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: _importFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import CSV/TXT'),
              ),
            ],
          ),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('${i + 1}')),
                  Expanded(
                    child: TextField(
                      controller: _rows[i].text,
                      decoration: const InputDecoration(
                        hintText: 'Word or sentence',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _rows[i].language,
                    items: [
                      for (final l in _languages)
                        DropdownMenuItem(value: l, child: Text(l.toUpperCase())),
                    ],
                    onChanged: (v) => setState(() => _rows[i].language = v!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove row',
                    onPressed: () => setState(() {
                      _rows.removeAt(i).text.dispose();
                    }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(_WordRow())),
              icon: const Icon(Icons.add),
              label: const Text('Add row'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit words'),
          ),
        ],
      ),
    );
  }
}

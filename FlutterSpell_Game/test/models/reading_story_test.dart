import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/models/reading_story.dart';

Word _w(int id, String text, {String language = 'english'}) =>
    Word(id: id, text: text, language: language);

void main() {
  test('English units and matching ignore case and punctuation', () {
    final units = readingUnits('The dog, flew high!', chinese: false);
    expect(units, ['the', 'dog', 'flew', 'high']);
    final read = unitsRead(units, 'the DOG flew', chinese: false);
    expect(read, [true, true, true, false]);
    expect(readCoverage(read), 0.75);
  });

  test('a repeated English word must be said twice', () {
    final units = readingUnits('go go now', chinese: false);
    expect(unitsRead(units, 'go now', chinese: false), [true, false, true]);
  });

  test('Chinese units skip punctuation and accept homophones', () {
    final units = readingUnits('小狗，飞！', chinese: true);
    expect(units, ['小', '狗', '飞']);
    expect(unitsRead(units, '小狗飞', chinese: true), [true, true, true]);
    expect(unitsRead(units, '', chinese: true), [false, false, false]);
  });

  test('spelling story uses only words of the chosen language', () {
    final story = buildSpellingStory(
      [_w(1, 'cat'), _w(2, 'boat'), _w(3, '猫', language: 'chinese')],
      chinese: false,
      random: Random(1),
    )!;
    expect(story.sentences.length, 2);
    expect(story.sentences.every((s) => !s.contains('猫')), isTrue);
    expect(story.wordForSentence.length, 2);
    expect(buildSpellingStory([_w(3, '猫', language: 'chinese')],
        chinese: false), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class ChineseLessonScreen extends StatelessWidget {
  final int lessonNumber;

  const ChineseLessonScreen({
    Key? key,
    this.lessonNumber = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock lesson data based on lesson number
    final lessonData = _getLessonData(lessonNumber);

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Lesson ${lessonData['number']}',
            style: DuolingoTextStyles.pageTitle),
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
              SizedBox(height: DuolingoSpacing.md),
              // Section badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.md,
                  vertical: DuolingoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DuolingoColors.chineseKingdomGradient[0],
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
                child: Text(
                  lessonData['section'] as String,
                  style: DuolingoTextStyles.label.copyWith(
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              // Lesson title
              Text(
                lessonData['title'] as String,
                style: DuolingoTextStyles.pageTitle,
              ),
              SizedBox(height: DuolingoSpacing.md),
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${lessonData['progress']}%',
                    style: DuolingoTextStyles.body,
                  ),
                  Text(
                    'Accuracy: ${lessonData['accuracy']}%',
                    style: DuolingoTextStyles.body.copyWith(
                      color: DuolingoColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: DuolingoSpacing.md),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(DuolingoSpacing.radiusButton),
                child: LinearProgressIndicator(
                  value: (lessonData['progress'] as int) / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    DuolingoColors.primaryGreen,
                  ),
                  minHeight: DuolingoSpacing.progressBarHeight + 2,
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Lesson content section
              _LessonContentSection(
                words: lessonData['words'] as List<Map<String, String>>,
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: '⏱️',
                      label: 'Time Spent',
                      value: '${lessonData['timeSpent']} min',
                    ),
                  ),
                  SizedBox(width: DuolingoSpacing.md),
                  Expanded(
                    child: _StatTile(
                      icon: '⭐',
                      label: 'Stars Earned',
                      value: '${lessonData['stars']}/3',
                    ),
                  ),
                ],
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Start Practice Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuolingoColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: DuolingoSpacing.lg,
                    ),
                    elevation: 4,
                    shadowColor: DuolingoColors.primaryGreen.withOpacity(0.5),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Starting practice session...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Practice ',
                        style: DuolingoTextStyles.cardTitle.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '▶',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
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

  Map<String, dynamic> _getLessonData(int lessonNum) {
    // Mock data for different lessons
    const lessons = [
      {
        'number': 'Lesson 1',
        'title': 'Hello & Basics',
        'section': 'Forest',
        'progress': 100,
        'accuracy': 95,
        'timeSpent': 12,
        'stars': 3,
        'words': [
          {'chinese': '你好', 'pinyin': 'nǐ hǎo', 'english': 'Hello'},
          {'chinese': '我', 'pinyin': 'wǒ', 'english': 'I/Me'},
          {'chinese': '你', 'pinyin': 'nǐ', 'english': 'You'},
          {'chinese': '是', 'pinyin': 'shì', 'english': 'To be'},
        ],
      },
      {
        'number': 'Lesson 2',
        'title': 'Numbers & Counting',
        'section': 'Forest',
        'progress': 75,
        'accuracy': 88,
        'timeSpent': 10,
        'stars': 2,
        'words': [
          {'chinese': '一', 'pinyin': 'yī', 'english': 'One'},
          {'chinese': '二', 'pinyin': 'èr', 'english': 'Two'},
          {'chinese': '三', 'pinyin': 'sān', 'english': 'Three'},
          {'chinese': '十', 'pinyin': 'shí', 'english': 'Ten'},
        ],
      },
      {
        'number': 'Lesson 3',
        'title': 'Family Members',
        'section': 'Forest',
        'progress': 50,
        'accuracy': 72,
        'timeSpent': 8,
        'stars': 1,
        'words': [
          {'chinese': '妈妈', 'pinyin': 'māma', 'english': 'Mother'},
          {'chinese': '爸爸', 'pinyin': 'bàba', 'english': 'Father'},
          {'chinese': '哥哥', 'pinyin': 'gēge', 'english': 'Older Brother'},
          {'chinese': '妹妹', 'pinyin': 'mèimei', 'english': 'Younger Sister'},
        ],
      },
    ];

    // Return mock data for lesson, cycle through if out of range
    int index = (lessonNum - 1) % lessons.length;
    return lessons[index];
  }
}

class _LessonContentSection extends StatelessWidget {
  final List<Map<String, String>> words;

  const _LessonContentSection({
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vocabulary',
          style: DuolingoTextStyles.sectionTitle,
        ),
        SizedBox(height: DuolingoSpacing.md),
        ...words.map((word) {
          return _WordCard(
            chinese: word['chinese']!,
            pinyin: word['pinyin']!,
            english: word['english']!,
          );
        }).toList(),
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  final String chinese;
  final String pinyin;
  final String english;

  const _WordCard({
    required this.chinese,
    required this.pinyin,
    required this.english,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: DuolingoSpacing.md),
      padding: EdgeInsets.all(DuolingoSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF9E6),
            Color(0xFFFFEFCC),
          ],
        ),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(
          color: DuolingoColors.chineseKingdomGradient[1].withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chinese,
                  style: DuolingoTextStyles.pageTitle,
                ),
                SizedBox(height: DuolingoSpacing.xs),
                Text(
                  pinyin,
                  style: DuolingoTextStyles.body.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.xs),
                Text(
                  english,
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.informationBlue,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: Play pronunciation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing pronunciation for: $chinese'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.all(DuolingoSpacing.md),
              decoration: BoxDecoration(
                color: DuolingoColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '🔊',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DuolingoSpacing.md),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(
          color: Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 24),
          ),
          SizedBox(height: DuolingoSpacing.xs),
          Text(
            label,
            style: DuolingoTextStyles.label,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: DuolingoSpacing.xs),
          Text(
            value,
            style: DuolingoTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

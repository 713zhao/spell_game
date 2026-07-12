import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Adventure World', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(DuolingoSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: DuolingoSpacing.xl),
                // Village Center
                _LocationNode(
                  icon: '🏘️',
                  label: 'Village',
                  color: DuolingoColors.neutralGray,
                  onTap: () => Navigator.pop(context),
                ),
                SizedBox(height: DuolingoSpacing.xxl),
                // Kingdom Nodes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _LocationNode(
                      icon: '🏰',
                      label: 'English\nKingdom',
                      color: DuolingoColors.englishKingdomGradient[0],
                      onTap: () => print('English Kingdom tapped'),
                    ),
                    _LocationNode(
                      icon: '🐉',
                      label: 'Chinese\nKingdom',
                      color: DuolingoColors.chineseKingdomGradient[0],
                      onTap: () => print('Chinese Kingdom tapped'),
                    ),
                  ],
                ),
                SizedBox(height: DuolingoSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _LocationNode(
                      icon: '🔍',
                      label: 'Review\nCave',
                      color: DuolingoColors.reviewCaveGradient[0],
                      onTap: () => print('Review Cave tapped'),
                    ),
                    _LocationNode(
                      icon: '🏝️',
                      label: 'Treasure\nIsland',
                      color: DuolingoColors.treasureIslandGradient[0],
                      onTap: () => print('Treasure Island tapped'),
                    ),
                  ],
                ),
                SizedBox(height: DuolingoSpacing.xxl),
                // Boss Arena
                _LocationNode(
                  icon: '⚔️',
                  label: 'Boss Arena',
                  color: DuolingoColors.bossArenaGradient[0],
                  onTap: () => print('Boss Arena tapped'),
                ),
                SizedBox(height: DuolingoSpacing.xl),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
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
              // Already on world-map
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

class _LocationNode extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LocationNode({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: DuolingoSpacing.nodeSize + 20,
            height: DuolingoSpacing.nodeSize + 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: DuolingoShadows.cardShadow,
            ),
            child: Center(
              child: Text(icon, style: TextStyle(fontSize: 40)),
            ),
          ),
          SizedBox(height: DuolingoSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.cardTitle,
          ),
        ],
      ),
    );
  }
}

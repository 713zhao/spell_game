import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class BackpackScreen extends StatefulWidget {
  const BackpackScreen({Key? key}) : super(key: key);

  @override
  State<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends State<BackpackScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Backpack', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tabs
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 0),
                  child: Container(
                    padding: EdgeInsets.all(DuolingoSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedTab == 0 ? DuolingoColors.primaryGreen : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      '🐾 Pets',
                      textAlign: TextAlign.center,
                      style: DuolingoTextStyles.cardTitle.copyWith(
                        color: _selectedTab == 0 ? DuolingoColors.primaryGreen : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: Container(
                    padding: EdgeInsets.all(DuolingoSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedTab == 1 ? DuolingoColors.primaryGreen : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      '🎖️ Badges',
                      textAlign: TextAlign.center,
                      style: DuolingoTextStyles.cardTitle.copyWith(
                        color: _selectedTab == 1 ? DuolingoColors.primaryGreen : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Expanded(
            child: _selectedTab == 0 ? _buildPetsTab() : _buildBadgesTab(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
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
              // Already on backpack
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

  Widget _buildPetsTab() {
    final pets = [
      ('🐼', 'Panda', 'Equipped', true),
      ('🦊', 'Fox', 'Equip', false),
      ('🐧', 'Penguin', 'Equip', false),
      ('🐵', 'Monkey', 'Unlock 50 Gems', false),
    ];

    return GridView.builder(
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DuolingoSpacing.lg,
        mainAxisSpacing: DuolingoSpacing.lg,
      ),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        final (icon, name, action, equipped) = pets[index];
        return Container(
          decoration: BoxDecoration(
            color: equipped ? DuolingoColors.primaryGreen.withOpacity(0.1) : DuolingoColors.neutralGray,
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
            border: equipped ? Border.all(color: DuolingoColors.primaryGreen, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(fontSize: 40)),
              SizedBox(height: DuolingoSpacing.sm),
              Text(name, style: DuolingoTextStyles.cardTitle),
              SizedBox(height: DuolingoSpacing.sm),
              GestureDetector(
                onTap: () => print('$action tapped'),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DuolingoSpacing.md,
                    vertical: DuolingoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: equipped ? DuolingoColors.primaryGreen : Colors.grey,
                    borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                  child: Text(
                    action,
                    style: DuolingoTextStyles.label.copyWith(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab() {
    final badges = [
      ('🎖️', 'Perfect Day', '10/10', true),
      ('🎖️', 'Streak Master', '7 days', true),
      ('🎖️', 'Boss Slayer', '0/5', false),
      ('🎖️', 'Gem Collector', '2/100', false),
    ];

    return GridView.builder(
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DuolingoSpacing.lg,
        mainAxisSpacing: DuolingoSpacing.lg,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final (icon, name, progress, completed) = badges[index];
        return Container(
          decoration: BoxDecoration(
            color: completed ? DuolingoColors.rewardYellow.withOpacity(0.1) : DuolingoColors.neutralGray,
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
            border: completed ? Border.all(color: DuolingoColors.rewardYellow, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(fontSize: 40)),
              SizedBox(height: DuolingoSpacing.sm),
              Text(name, style: DuolingoTextStyles.cardTitle, textAlign: TextAlign.center),
              SizedBox(height: DuolingoSpacing.xs),
              Text(progress, style: DuolingoTextStyles.label),
              if (!completed)
                Padding(
                  padding: EdgeInsets.only(top: DuolingoSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress == '2/100' ? 0.02 : 0.0,
                      minHeight: 4,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation(DuolingoColors.primaryGreen),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

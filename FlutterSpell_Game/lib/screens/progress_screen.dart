import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Progress', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Grid
              Text('Stats', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.md),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: DuolingoSpacing.md,
                mainAxisSpacing: DuolingoSpacing.md,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _StatCard('250', 'Total XP', DuolingoColors.rewardYellow),
                  _StatCard('8', 'Current Streak', DuolingoColors.streakOrange),
                  _StatCard('85', 'Total Coins', DuolingoColors.primaryGreen),
                  _StatCard('12', 'Total Gems', DuolingoColors.treasureGold),
                  _StatCard('10', 'Levels Completed', DuolingoColors.informationBlue),
                  _StatCard('5', 'Bosses Defeated', DuolingoColors.mistakeRed),
                ],
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Milestones
              Text('Milestones', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.md),
              _MilestoneItem('🏁', 'Stage 1 Complete (Vowels)', true),
              _MilestoneItem('🏁', 'Stage 5 Complete (Review)', true),
              _MilestoneItem('🏁', 'Boss 1 Defeated', true),
              _MilestoneItem('🏁', '7-Day Streak Achieved', true),
              _MilestoneItem('🏁', '100 XP Milestone', false),
              _MilestoneItem('🏁', 'First Gem Earned', false),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World Map'),
          BottomNavigationBarItem(icon: Icon(Icons.backpack), label: 'Backpack'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: DuolingoTextStyles.pageTitle.copyWith(color: color)),
          SizedBox(height: DuolingoSpacing.xs),
          Text(label, style: DuolingoTextStyles.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool completed;

  const _MilestoneItem(this.icon, this.label, this.completed);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: DuolingoSpacing.md),
      padding: EdgeInsets.all(DuolingoSpacing.md),
      decoration: BoxDecoration(
        color: completed ? DuolingoColors.primaryGreen.withOpacity(0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border(
          left: BorderSide(
            color: completed ? DuolingoColors.primaryGreen : Colors.grey,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 24)),
          SizedBox(width: DuolingoSpacing.md),
          Expanded(
            child: Text(
              label,
              style: DuolingoTextStyles.body.copyWith(
                color: completed ? DuolingoColors.darkText : Colors.grey[600],
                fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (completed) Text('✓', style: TextStyle(color: DuolingoColors.primaryGreen, fontSize: 20)),
        ],
      ),
    );
  }
}

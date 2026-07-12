import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class ChineseKingdomScreen extends StatelessWidget {
  const ChineseKingdomScreen({Key? key}) : super(key: key);

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
            children: [
              SizedBox(height: DuolingoSpacing.md),
              // Forest Section
              _SectionCard(
                icon: '🌲',
                title: 'Forest',
                subtitle: 'Lessons 1-10',
                completed: 7,
                total: 10,
                isLocked: false,
                progressColor: DuolingoColors.primaryGreen,
                onTap: () {
                  Navigator.of(context).pushNamed('/chinese-lesson', arguments: 1);
                },
              ),
              SizedBox(height: DuolingoSpacing.lg),
              // River Section (Locked)
              _SectionCard(
                icon: '🌊',
                title: 'River',
                subtitle: 'Lessons 11-20',
                completed: 0,
                total: 10,
                isLocked: true,
                progressColor: DuolingoColors.neutralGray,
                lockedReason: 'Complete Forest to unlock',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete Forest section to unlock River'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              SizedBox(height: DuolingoSpacing.lg),
              // Mountain Section (Locked)
              _SectionCard(
                icon: '⛰️',
                title: 'Mountain',
                subtitle: 'Lessons 21-30',
                completed: 0,
                total: 10,
                isLocked: true,
                progressColor: DuolingoColors.neutralGray,
                lockedReason: 'Complete River to unlock',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete River section to unlock Mountain'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
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
}

class _SectionCard extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final int completed;
  final int total;
  final bool isLocked;
  final Color progressColor;
  final String? lockedReason;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.total,
    required this.isLocked,
    required this.progressColor,
    this.lockedReason,
    required this.onTap,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final progress = widget.total > 0 ? widget.completed / widget.total : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: DuolingoColors.backgroundWhite,
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
            border: Border.all(
              color: widget.isLocked ? DuolingoColors.secondaryButtonGray : Colors.transparent,
              width: 1,
            ),
            boxShadow: _isHovered && !widget.isLocked
                ? DuolingoShadows.cardHoverShadow
                : DuolingoShadows.cardShadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                        SizedBox(width: DuolingoSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: DuolingoTextStyles.pageTitle.copyWith(
                                  color: widget.isLocked
                                      ? DuolingoColors.bodyText
                                      : DuolingoColors.darkText,
                                ),
                              ),
                              SizedBox(height: DuolingoSpacing.xs),
                              Text(
                                widget.subtitle,
                                style: DuolingoTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                        if (!widget.isLocked)
                          Text(
                            '${widget.completed}/${widget.total}',
                            style: DuolingoTextStyles.largeValue.copyWith(
                              color: widget.progressColor,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: DuolingoSpacing.lg),
                    if (!widget.isLocked) ...[
                      // Progress bar
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DuolingoSpacing.radiusButton),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.progressColor,
                          ),
                          minHeight: DuolingoSpacing.progressBarHeight,
                        ),
                      ),
                      SizedBox(height: DuolingoSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}% Complete',
                            style: DuolingoTextStyles.label.copyWith(
                              color: DuolingoColors.bodyText,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DuolingoSpacing.md,
                              vertical: DuolingoSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: widget.progressColor.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(DuolingoSpacing.radiusButton),
                            ),
                            child: Text(
                              'Enter',
                              style: DuolingoTextStyles.label.copyWith(
                                color: widget.progressColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Locked state
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.lock,
                              color: DuolingoColors.neutralGray,
                              size: 32,
                            ),
                            SizedBox(height: DuolingoSpacing.sm),
                            Text(
                              widget.lockedReason ?? 'Locked',
                              style: DuolingoTextStyles.body.copyWith(
                                color: DuolingoColors.bodyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

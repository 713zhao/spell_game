import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool disabled;

  const PrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.disabled = false,
  }) : super(key: key);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.disabled) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.disabled) {
      _animationController.reverse();
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () {
        if (!widget.disabled) {
          _animationController.reverse();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: DuolingoSpacing.minTouchTarget,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.disabled
                  ? [Colors.grey, Colors.grey.shade400]
                  : [DuolingoColors.primaryGreen, Color(0xFF7ed321)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
            boxShadow: widget.disabled
                ? []
                : DuolingoShadows.primaryButtonShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.disabled ? null : widget.onPressed,
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.label,
                        style: DuolingoTextStyles.cardTitle.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

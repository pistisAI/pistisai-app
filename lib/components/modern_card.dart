import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Modern card component with hover effects matching homepage design
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableHover;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.enableHover = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.01).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (!widget.enableHover) return;

    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center, // Ensure scaling is centered
            child: Container(
              width: widget.width,
              height: widget.height,
              margin: widget.margin ?? EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.colorsOf(context).backgroundCard,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                border: Border.all(
                  color: _isHovered
                      ? AppTheme.colorsOf(context).primary
                      : AppTheme.colorsOf(context).secondary.withValues(alpha: 0.27),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? AppTheme.colorsOf(context).primary.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                    blurRadius: _isHovered ? 32 : 24,
                    offset: Offset(0, _isHovered ? 8 : 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                child: widget.onTap != null
                    ? InkWell(
                        onTap: widget.onTap,
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                        child: Container(
                          padding: widget.padding ??
                              EdgeInsets.all(AppTheme.spacingL),
                          child: widget.child,
                        ),
                      )
                    : Container(
                        padding:
                            widget.padding ?? EdgeInsets.all(AppTheme.spacingL),
                        child: widget.child,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

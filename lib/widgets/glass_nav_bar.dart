import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'glass.dart';

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color accent;

  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.accent,
  });
}

/// Dynamic Liquid Glass Bottom Navigation Bar.
///
/// Features:
/// - Real-time Interactive Drag / Pan: When pressing and holding or dragging,
///   the liquid glass pill fluidly follows the finger position and dynamically
///   morphs, stretches, and blends colors across all navigation tabs.
/// - Magnetic Snap: On release, springs into the nearest tab with elastic physics.
/// - Multi-layered frosted refraction with top-edge specular liquid sheen.
/// - Reactive ambient aura that smoothly transitions to the active neon accent.
class GlassNavBar extends StatefulWidget {
  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final PageController? pageController;

  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.pageController,
  });

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  bool _isDragging = false;
  double? _dragFraction;
  int? _lastHapticIndex;

  static const double _barHeight = 66.0;
  static const double _horizontalPadding = 6.0;
  static const double _verticalPadding = 5.0;
  static const double _borderRadius = 26.0;

  @override
  void initState() {
    super.initState();
    widget.pageController?.addListener(_onPageScroll);
  }

  @override
  void didUpdateWidget(GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_onPageScroll);
      widget.pageController?.addListener(_onPageScroll);
    }
  }

  @override
  void dispose() {
    widget.pageController?.removeListener(_onPageScroll);
    super.dispose();
  }

  void _onPageScroll() {
    if (!_isDragging && mounted) {
      setState(() {});
    }
  }

  double _getEffectiveFraction() {
    if (_isDragging && _dragFraction != null) {
      return _dragFraction!.clamp(0.0, (widget.items.length - 1).toDouble());
    }
    if (widget.pageController != null && widget.pageController!.hasClients) {
      final page = widget.pageController!.page;
      if (page != null) {
        return page.clamp(0.0, (widget.items.length - 1).toDouble());
      }
    }
    return widget.currentIndex.clamp(0, widget.items.length - 1).toDouble();
  }

  Color _calculateLiquidColor(double fraction) {
    final clamped = fraction.clamp(0.0, (widget.items.length - 1).toDouble());
    final lower = clamped.floor();
    final upper = clamped.ceil();
    final t = clamped - lower;
    if (lower == upper) {
      return widget.items[lower].accent;
    }
    return Color.lerp(widget.items[lower].accent, widget.items[upper].accent, t) ??
        widget.items[lower].accent;
  }

  void _checkHapticHover(double fraction) {
    final hoveredIndex = fraction.round().clamp(0, widget.items.length - 1);
    if (_lastHapticIndex != hoveredIndex) {
      _lastHapticIndex = hoveredIndex;
      HapticFeedback.selectionClick();
    }
  }

  void _onDragStart(DragStartDetails details, double itemWidth) {
    final fraction = ((details.localPosition.dx - _horizontalPadding) / itemWidth)
        .clamp(0.0, (widget.items.length - 1).toDouble());
    final hoveredIndex = fraction.round().clamp(0, widget.items.length - 1);
    _lastHapticIndex = hoveredIndex;
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = true;
      _dragFraction = fraction;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double itemWidth) {
    final fraction = ((details.localPosition.dx - _horizontalPadding) / itemWidth)
        .clamp(0.0, (widget.items.length - 1).toDouble());
    _checkHapticHover(fraction);
    setState(() {
      _dragFraction = fraction;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final current = _dragFraction ?? widget.currentIndex.toDouble();
    final target = current.round().clamp(0, widget.items.length - 1);
    _lastHapticIndex = null;
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = false;
      _dragFraction = null;
    });
    widget.onTap(target);
  }

  void _onDragCancel() {
    if (!_isDragging) return;
    _lastHapticIndex = null;
    setState(() {
      _isDragging = false;
      _dragFraction = null;
    });
  }

  void _onLongPressStart(LongPressStartDetails details, double itemWidth) {
    final fraction = ((details.localPosition.dx - _horizontalPadding) / itemWidth)
        .clamp(0.0, (widget.items.length - 1).toDouble());
    final hoveredIndex = fraction.round().clamp(0, widget.items.length - 1);
    _lastHapticIndex = hoveredIndex;
    HapticFeedback.mediumImpact();
    setState(() {
      _isDragging = true;
      _dragFraction = fraction;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details, double itemWidth) {
    final fraction = ((details.localPosition.dx - _horizontalPadding) / itemWidth)
        .clamp(0.0, (widget.items.length - 1).toDouble());
    _checkHapticHover(fraction);
    setState(() {
      _dragFraction = fraction;
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _onDragEnd(DragEndDetails());
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFraction = _getEffectiveFraction();
    final activeColor = _calculateLiquidColor(effectiveFraction);
    final activeHoverIndex = effectiveFraction.round().clamp(0, widget.items.length - 1);

    return Semantics(
      container: true,
      label: 'Bottom Navigation Bar',
      child: SizedBox(
        height: _barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Frosted Glass Chassis (Background, Blur & Rim Border)
            Positioned.fill(
              child: AnimatedContainer(
                duration: Duration(milliseconds: _isDragging ? 80 : 360),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_borderRadius),
                  boxShadow: [
                    // Deep ambient floor shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    // Dynamic liquid colored aura reacting to active position & drag
                    BoxShadow(
                      color: activeColor.withValues(alpha: _isDragging ? 0.35 : 0.22),
                      blurRadius: _isDragging ? 30 : 24,
                      spreadRadius: _isDragging ? 0 : -2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_borderRadius),
                  child: BackdropFilter(
                    filter: kGlassBlur,
                    child: CustomPaint(
                      foregroundPainter: _LiquidGlassChassisPainter(
                        accent: activeColor,
                        radius: _borderRadius,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_borderRadius),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xEE0B1222),
                              const Color(0xDD0F172A),
                              activeColor.withValues(alpha: _isDragging ? 0.12 : 0.06),
                            ],
                            stops: const [0.0, 0.65, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Interactive Liquid Layer (Pill + Nav Items) - Free to overflow border!
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: _verticalPadding,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double totalWidth = constraints.maxWidth;
                    final double itemWidth = totalWidth / widget.items.length;
                    final double pillHeight = constraints.maxHeight;

                    // Elastic liquid deformation when dragging
                    final double stretch = _isDragging ? 8.0 : 0.0;
                    final double pillWidth = (itemWidth - 4.0 + stretch).clamp(20.0, totalWidth);
                    final double pillLeft = (effectiveFraction * itemWidth + 2.0 - stretch / 2)
                        .clamp(0.0, totalWidth - pillWidth);

                    final bool isUserScreenSwiping = widget.pageController?.hasClients == true &&
                        widget.pageController!.position.userScrollDirection != ScrollDirection.idle;

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (d) => _onDragStart(d, itemWidth),
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d, itemWidth),
                      onHorizontalDragEnd: _onDragEnd,
                      onHorizontalDragCancel: _onDragCancel,
                      onLongPressStart: (d) => _onLongPressStart(d, itemWidth),
                      onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(d, itemWidth),
                      onLongPressEnd: _onLongPressEnd,
                      onLongPressCancel: _onDragCancel,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Gliding Liquid Droplet Pill Indicator
                          AnimatedPositioned(
                            duration: Duration(
                              milliseconds: _isDragging ? 40 : (isUserScreenSwiping ? 0 : 280),
                            ),
                            curve: _isDragging || isUserScreenSwiping
                                ? Curves.linear
                                : Curves.easeOutCubic,
                            left: pillLeft,
                            top: 0,
                            width: pillWidth,
                            height: pillHeight,
                            child: _LiquidGlidingPill(
                              accent: activeColor,
                              isDragging: _isDragging,
                            ),
                          ),

                          // Navigation Items Row (6 clean tabs with ample width)
                          Row(
                            children: [
                              for (var i = 0; i < widget.items.length; i++)
                                Expanded(
                                  child: _LiquidNavButton(
                                    item: widget.items[i],
                                    selected: i == activeHoverIndex,
                                    onTap: () {
                                      if (!_isDragging) {
                                        HapticFeedback.selectionClick();
                                        widget.onTap(i);
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The animated fluid capsule that slides beneath the active tab.
class _LiquidGlidingPill extends StatelessWidget {
  final Color accent;
  final bool isDragging;

  const _LiquidGlidingPill({
    required this.accent,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;

    return AnimatedScale(
      scale: isDragging ? 1.28 : 1.0,
      duration: Duration(milliseconds: isDragging ? 180 : 280),
      curve: isDragging ? Curves.easeOutBack : Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: Duration(milliseconds: isDragging ? 50 : 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: isDragging ? 0.42 : 0.28),
              accent.withValues(alpha: isDragging ? 0.22 : 0.12),
            ],
          ),
          boxShadow: [
            // Inner/outer liquid glow magnified when zoomed
            BoxShadow(
              color: accent.withValues(alpha: isDragging ? 0.65 : 0.40),
              blurRadius: isDragging ? 26 : 16,
              spreadRadius: isDragging ? 2 : -2,
              offset: Offset(0, isDragging ? 4 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Liquid top specular reflection (sheen)
              Positioned(
                top: 0,
                left: 4,
                right: 4,
                height: 2.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: isDragging ? 0.95 : 0.65),
                        accent.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
              // Dynamic subtle border
              CustomPaint(
                size: Size.infinite,
                painter: _LiquidPillBorderPainter(
                  accent: accent,
                  radius: radius,
                  isDragging: isDragging,
                ),
              ),
              // Bottom glowing droplet pip
              Positioned(
                bottom: 3.5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isDragging ? 22 : 14,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 1.0),
                        blurRadius: isDragging ? 10 : 6,
                        spreadRadius: isDragging ? 2 : 1,
                      ),
                    ],
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

/// Custom painter for the dynamic liquid pill's perimeter rim.
class _LiquidPillBorderPainter extends CustomPainter {
  final Color accent;
  final double radius;
  final bool isDragging;

  const _LiquidPillBorderPainter({
    required this.accent,
    required this.radius,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      Radius.circular(radius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 1.4 : 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDragging ? 0.75 : 0.55),
          accent.withValues(alpha: isDragging ? 0.8 : 0.6),
          accent.withValues(alpha: isDragging ? 0.25 : 0.15),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidPillBorderPainter old) =>
      old.accent != accent || old.radius != radius || old.isDragging != isDragging;
}

/// Custom painter for the entire outer chassis rim (liquid specular light).
class _LiquidGlassChassisPainter extends CustomPainter {
  final Color accent;
  final double radius;

  const _LiquidGlassChassisPainter({
    required this.accent,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      Radius.circular(radius),
    );

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          SysDashColors.glassBorderHighlight,
          Colors.white.withValues(alpha: 0.12),
          accent.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassChassisPainter old) =>
      old.accent != accent || old.radius != radius;
}

/// Interactive button in the liquid nav bar.
class _LiquidNavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _LiquidNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? item.accent : SysDashColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: item.accent.withValues(alpha: 0.18),
          highlightColor: item.accent.withValues(alpha: 0.08),
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.14 : 1.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 20,
                      color: color,
                      shadows: selected
                          ? [
                              Shadow(
                                color: item.accent.withValues(alpha: 0.8),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 3.5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: selected
                          ? SysDashColors.textPrimary
                          : SysDashColors.textSecondary.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    child: Text(item.label, maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

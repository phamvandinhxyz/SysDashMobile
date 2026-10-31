import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
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

class _GlassNavBarState extends State<GlassNavBar> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  bool _isFlinging = false;
  double? _dragFraction;
  double _dragOffset = 0.0;
  int? _lastHapticIndex;

  Offset _pointerDownPosition = Offset.zero;
  DateTime _pointerDownTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _pointerHasMoved = false;
  VelocityTracker? _velocityTracker;

  late final AnimationController _flingController;
  Animation<double>? _flingAnimation;

  static const double _barHeight = 66.0;
  static const double _horizontalPadding = 6.0;
  static const double _verticalPadding = 5.0;
  static const double _borderRadius = 26.0;

  @override
  void initState() {
    super.initState();
    _flingController = AnimationController(vsync: this);
    _flingController.addListener(_onFlingTick);
    _flingController.addStatusListener(_onFlingStatus);
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
    _flingController.dispose();
    widget.pageController?.removeListener(_onPageScroll);
    super.dispose();
  }

  void _onPageScroll() {
    if (!_isDragging && !_isFlinging && mounted) {
      setState(() {});
    }
  }

  void _onFlingTick() {
    if (_isFlinging && _flingAnimation != null && mounted) {
      final value = _flingAnimation!.value;
      _checkHapticHover(value);
      setState(() {
        _dragFraction = value.clamp(0.0, (widget.items.length - 1).toDouble());
      });
    }
  }

  void _onFlingStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      final target = _dragFraction?.round().clamp(0, widget.items.length - 1) ?? widget.currentIndex;
      _lastHapticIndex = null;
      HapticFeedback.lightImpact();
      setState(() {
        _isFlinging = false;
        _dragFraction = null;
      });
      widget.onTap(target);
    }
  }

  double _getEffectiveFraction() {
    if ((_isDragging || _isFlinging) && _dragFraction != null) {
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

  void _onPointerDown(PointerDownEvent event, double itemWidth) {
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _pointerDownPosition = event.localPosition;
    _pointerDownTime = DateTime.now();
    _pointerHasMoved = false;

    if (_isFlinging) {
      _flingController.stop();
      _isFlinging = false;
    }

    final currentFraction = _getEffectiveFraction();
    final touchFraction = ((event.localPosition.dx - _horizontalPadding) / itemWidth)
        .clamp(0.0, (widget.items.length - 1).toDouble());

    // Instant zero-delay capsule lock-on: if touching on or near the capsule (within 0.95 tabs),
    // immediately latch and activate liquid expansion with 0ms delay!
    if ((touchFraction - currentFraction).abs() < 0.95) {
      _isDragging = true;
      _dragFraction = currentFraction;
      _dragOffset = touchFraction - currentFraction;
      final hoveredIndex = currentFraction.round().clamp(0, widget.items.length - 1);
      _lastHapticIndex = hoveredIndex;
      HapticFeedback.lightImpact();
      setState(() {});
    } else {
      _dragOffset = 0.0;
    }
  }

  void _onPointerMove(PointerMoveEvent event, double itemWidth) {
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final touchFraction = ((event.localPosition.dx - _horizontalPadding) / itemWidth)
        .clamp(0.0, (widget.items.length - 1).toDouble());

    final moveDist = (event.localPosition - _pointerDownPosition).distance;
    if (moveDist > 3.0) {
      _pointerHasMoved = true;
      if (!_isDragging) {
        _isDragging = true;
        _dragOffset = 0.0;
        final hoveredIndex = touchFraction.round().clamp(0, widget.items.length - 1);
        _lastHapticIndex = hoveredIndex;
        HapticFeedback.lightImpact();
      }
    }

    if (_isDragging) {
      final newFraction = (touchFraction - _dragOffset)
          .clamp(0.0, (widget.items.length - 1).toDouble());
      _checkHapticHover(newFraction);
      setState(() {
        _dragFraction = newFraction;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event, double itemWidth) {
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final estimate = _velocityTracker?.getVelocityEstimate();
    final velocity = estimate?.pixelsPerSecond.dx ?? 0.0;
    final duration = DateTime.now().difference(_pointerDownTime);
    final totalDist = (event.localPosition - _pointerDownPosition).distance;

    // Pure tap: lifted without substantial drag or flick
    if (!_pointerHasMoved && totalDist < 12.0 && duration.inMilliseconds < 350 && velocity.abs() < 180.0) {
      final tappedIndex = ((event.localPosition.dx - _horizontalPadding) / itemWidth)
          .round()
          .clamp(0, widget.items.length - 1);
      _lastHapticIndex = null;
      if (_isDragging) {
        setState(() {
          _isDragging = false;
          _dragFraction = null;
        });
      }
      HapticFeedback.selectionClick();
      widget.onTap(tappedIndex);
      return;
    }

    _startFling(velocity, itemWidth);
  }

  void _onPointerCancel(PointerCancelEvent event, double itemWidth) {
    if (_isDragging || _isFlinging) {
      _startFling(0.0, itemWidth);
    }
  }

  void _startFling(double velocityPxPerSec, double itemWidth) {
    if (!_isDragging && !_isFlinging) return;
    _flingController.stop();

    final currentFraction = _dragFraction ?? widget.currentIndex.toDouble();
    final maxIndex = (widget.items.length - 1).toDouble();

    // Convert pixel velocity to tabs/second
    final tabsPerSec = velocityPxPerSec / itemWidth;

    int targetIndex;
    if (tabsPerSec.abs() > 1.2) {
      // Significant flick force: project momentum based on release velocity
      final projected = currentFraction + tabsPerSec * 0.28;
      targetIndex = projected.round().clamp(0, widget.items.length - 1);

      // Ensure at least 1-step advance in flick direction
      if (tabsPerSec > 1.2 && targetIndex <= currentFraction.floor()) {
        targetIndex = (currentFraction.floor() + 1).clamp(0, widget.items.length - 1);
      } else if (tabsPerSec < -1.2 && targetIndex >= currentFraction.ceil()) {
        targetIndex = (currentFraction.ceil() - 1).clamp(0, widget.items.length - 1);
      }
    } else {
      // Slow release: snap to nearest tab
      targetIndex = currentFraction.round().clamp(0, widget.items.length - 1);
    }

    final distance = (targetIndex - currentFraction).abs();

    if (distance < 0.04) {
      _lastHapticIndex = null;
      setState(() {
        _isDragging = false;
        _isFlinging = false;
        _dragFraction = null;
      });
      widget.onTap(targetIndex);
      return;
    }

    // Dynamic duration based on distance (feels natural, responsive, and physical)
    final baseDurationMs = (200 + distance * 60).clamp(200.0, 440.0).toInt();
    _flingController.duration = Duration(milliseconds: baseDurationMs);

    _flingAnimation = Tween<double>(
      begin: currentFraction.clamp(0.0, maxIndex),
      end: targetIndex.toDouble().clamp(0.0, maxIndex),
    ).animate(CurvedAnimation(
      parent: _flingController,
      curve: Curves.easeOutCubic,
    ));

    setState(() {
      _isDragging = false;
      _isFlinging = true;
    });

    _flingController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    ThemeScope.maybeOf(context);
    final effectiveFraction = _getEffectiveFraction();
    final activeColor = _calculateLiquidColor(effectiveFraction);
    final activeHoverIndex = effectiveFraction.round().clamp(0, widget.items.length - 1);
    final isDark = SysDashColors.isDark;

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
                duration: Duration(milliseconds: (_isDragging || _isFlinging) ? 80 : 360),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_borderRadius),
                  boxShadow: [
                    // Deep ambient floor shadow
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : const Color(0x180F172A),
                      blurRadius: isDark ? 28 : 20,
                      offset: Offset(0, isDark ? 12 : 6),
                    ),
                    // Dynamic liquid colored aura reacting to active position & drag
                    BoxShadow(
                      color: activeColor.withValues(alpha: (_isDragging || _isFlinging) ? 0.35 : (isDark ? 0.22 : 0.14)),
                      blurRadius: (_isDragging || _isFlinging) ? 30 : 20,
                      spreadRadius: (_isDragging || _isFlinging) ? 0 : -2,
                      offset: const Offset(0, 4),
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
                              isDark ? const Color(0xEE0B1222) : const Color(0xF8FFFFFF),
                              isDark ? const Color(0xDD0F172A) : const Color(0xEEF8FAFC),
                              activeColor.withValues(alpha: (_isDragging || _isFlinging) ? 0.12 : (isDark ? 0.06 : 0.04)),
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

                    // Elastic liquid deformation when dragging or flinging
                    final double stretch = (_isDragging || _isFlinging) ? 8.0 : 0.0;
                    final double pillWidth = (itemWidth - 4.0 + stretch).clamp(20.0, totalWidth);
                    final double pillLeft = (effectiveFraction * itemWidth + 2.0 - stretch / 2)
                        .clamp(0.0, totalWidth - pillWidth);

                    final bool isUserScreenSwiping = widget.pageController?.hasClients == true &&
                        widget.pageController!.position.userScrollDirection != ScrollDirection.idle;

                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (e) => _onPointerDown(e, itemWidth),
                      onPointerMove: (e) => _onPointerMove(e, itemWidth),
                      onPointerUp: (e) => _onPointerUp(e, itemWidth),
                      onPointerCancel: (e) => _onPointerCancel(e, itemWidth),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Gliding Liquid Droplet Pill Indicator
                          AnimatedPositioned(
                            duration: Duration(
                              milliseconds: (_isDragging || _isFlinging) ? 0 : (isUserScreenSwiping ? 0 : 280),
                            ),
                            curve: _isDragging || _isFlinging || isUserScreenSwiping
                                ? Curves.linear
                                : Curves.easeOutCubic,
                            left: pillLeft,
                            top: 0,
                            width: pillWidth,
                            height: pillHeight,
                            child: _LiquidGlidingPill(
                              accent: activeColor,
                              isDragging: _isDragging || _isFlinging,
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
    final isDark = SysDashColors.isDark;

    return AnimatedScale(
      scale: isDragging ? 1.4 : 1.0,
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
              accent.withValues(alpha: isDragging ? 0.42 : (isDark ? 0.28 : 0.16)),
              accent.withValues(alpha: isDragging ? 0.22 : (isDark ? 0.12 : 0.08)),
            ],
          ),
          boxShadow: [
            // Inner/outer liquid glow magnified when zoomed
            BoxShadow(
              color: accent.withValues(alpha: isDragging ? 0.65 : (isDark ? 0.40 : 0.22)),
              blurRadius: isDragging ? 26 : 14,
              spreadRadius: isDragging ? 2 : -2,
              offset: Offset(0, isDragging ? 4 : 2),
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
    final isDark = SysDashColors.isDark;

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          SysDashColors.glassBorderHighlight,
          isDark ? Colors.white.withValues(alpha: 0.12) : SysDashColors.glassBorderSubtle,
          accent.withValues(alpha: isDark ? 0.45 : 0.35),
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

  const _LiquidNavButton({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? item.accent : SysDashColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
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
    );
  }
}

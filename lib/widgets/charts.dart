import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/server_models.dart';
import '../services/telemetry_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'glass.dart';

// =============================================================================
// Time range selector: Live · 1h · 12h · 24h · 1w · 30d
// =============================================================================
class TimeRangeSelector extends StatelessWidget {
  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;
  final Color accent;

  const TimeRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accent = SysDashColors.cpuCyan,
  });

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SysDashColors.glassBorderSubtle),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final range in TimeRange.values)
            _RangeChip(
              label: strings.timeRange(range),
              isLive: range == TimeRange.live,
              selected: range == selected,
              accent: accent,
              onTap: () => onChanged(range),
            ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool isLive;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.isLive,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: selected
                  ? LinearGradient(colors: [
                      accent.withValues(alpha: 0.34),
                      accent.withValues(alpha: 0.14),
                    ])
                  : null,
              border: Border.all(
                color: selected ? accent.withValues(alpha: 0.75) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLive) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SysDashColors.statusEmerald,
                      boxShadow: selected
                          ? [BoxShadow(color: SysDashColors.statusEmerald.withValues(alpha: 0.8), blurRadius: 6)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? SysDashColors.textPrimary : SysDashColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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

// =============================================================================
// Time-series chart with axes, time labels and touch scrubbing tooltip
// =============================================================================
class ChartSeries {
  final String label;
  final Color color;
  final List<TimedSample> samples;
  const ChartSeries({required this.label, required this.color, required this.samples});
}

class TimeSeriesChart extends StatefulWidget {
  final List<ChartSeries> series;
  final TimeRange range;
  final String unit;
  final double? fixedMax;
  final double height;

  const TimeSeriesChart({
    super.key,
    required this.series,
    required this.range,
    required this.unit,
    this.fixedMax,
    this.height = 170,
  });

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  int? _hoverIndex;
  Timer? _clearTimer;

  int get _length => widget.series.isEmpty ? 0 : widget.series.first.samples.length;

  void _hover(double dx, double width) {
    final n = _length;
    if (n < 2) return;
    final plotW = width - _TimeSeriesPainter.leftPad - _TimeSeriesPainter.rightPad;
    final ratio = ((dx - _TimeSeriesPainter.leftPad) / plotW).clamp(0.0, 1.0);
    final index = (ratio * (n - 1)).round();
    if (index != _hoverIndex) setState(() => _hoverIndex = index);
  }

  void _clear({Duration delay = Duration.zero}) {
    _clearTimer?.cancel();
    _clearTimer = Timer(delay, () {
      if (mounted) setState(() => _hoverIndex = null);
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.series.isEmpty ? null : widget.series.first;
    final latest = first == null || first.samples.isEmpty ? null : first.samples.last.value;

    return Semantics(
      label: '${first?.label ?? ''} ${latest == null ? '' : formatMetric(latest, widget.unit)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              _clearTimer?.cancel();
              _hover(d.localPosition.dx, width);
            },
            onTapUp: (_) => _clear(delay: const Duration(milliseconds: 1800)),
            onHorizontalDragStart: (d) {
              _clearTimer?.cancel();
              _hover(d.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (d) => _hover(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _clear(delay: const Duration(milliseconds: 900)),
            onHorizontalDragCancel: _clear,
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _TimeSeriesPainter(
                series: widget.series,
                range: widget.range,
                unit: widget.unit,
                fixedMax: widget.fixedMax,
                hoverIndex: _hoverIndex != null && _hoverIndex! < _length ? _hoverIndex : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimeSeriesPainter extends CustomPainter {
  static const double leftPad = 44;
  static const double rightPad = 6;
  static const double topPad = 8;
  static const double bottomPad = 22;

  final List<ChartSeries> series;
  final TimeRange range;
  final String unit;
  final double? fixedMax;
  final int? hoverIndex;

  _TimeSeriesPainter({
    required this.series,
    required this.range,
    required this.unit,
    required this.fixedMax,
    required this.hoverIndex,
  });

  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / exp;
    final nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
    return nice * exp;
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    Color color = SysDashColors.textMuted,
    double size = 9.5,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
    double maxX = double.infinity,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = switch (align) {
      TextAlign.center => anchor.dx - tp.width / 2,
      TextAlign.right => anchor.dx - tp.width,
      _ => anchor.dx,
    };
    dx = dx.clamp(0.0, math.max(0.0, maxX - tp.width));
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(leftPad, topPad, size.width - rightPad, size.height - bottomPad);
    if (series.isEmpty || series.first.samples.length < 2) return;
    final n = series.first.samples.length;

    double maxValue = 0;
    for (final s in series) {
      for (final p in s.samples) {
        maxValue = math.max(maxValue, p.value);
      }
    }
    final yMax = fixedMax ?? _niceCeil(maxValue * 1.15);

    // --- Grid & Y labels
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(
        canvas,
        formatMetric(yMax * i / 4, unit, compact: true),
        Offset(plot.left - 6, y),
        align: TextAlign.right,
      );
    }

    // --- X (time) labels
    const ticks = 4;
    for (var k = 0; k <= ticks; k++) {
      final idx = ((n - 1) * k / ticks).round();
      final x = plot.left + plot.width * idx / (n - 1);
      canvas.drawLine(
        Offset(x, plot.bottom),
        Offset(x, plot.bottom + 4),
        gridPaint,
      );
      _text(
        canvas,
        formatAxisTime(series.first.samples[idx].time, range),
        Offset(x, plot.bottom + 13),
        align: k == 0 ? TextAlign.left : (k == ticks ? TextAlign.right : TextAlign.center),
        maxX: size.width,
      );
    }

    Offset point(int i, double v) => Offset(
      plot.left + plot.width * i / (n - 1),
      plot.bottom - (v / yMax).clamp(0.0, 1.0) * plot.height,
    );

    // --- Series
    for (var s = 0; s < series.length; s++) {
      final data = series[s];
      final pts = [for (var i = 0; i < data.samples.length && i < n; i++) point(i, data.samples[i].value)];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        final cx = (p0.dx + p1.dx) / 2;
        path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }

      final fill = Path.from(path)
        ..lineTo(pts.last.dx, plot.bottom)
        ..lineTo(pts.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              data.color.withValues(alpha: s == 0 ? 0.32 : 0.14),
              data.color.withValues(alpha: 0.0),
            ],
          ).createShader(plot),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = data.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );

      if (range == TimeRange.live && hoverIndex == null) {
        canvas.drawCircle(pts.last, 5.5, Paint()..color = data.color.withValues(alpha: 0.3));
        canvas.drawCircle(pts.last, 2.8, Paint()..color = Colors.white);
      }
    }

    // --- Hover crosshair + tooltip
    final hi = hoverIndex;
    if (hi == null) return;
    final x = plot.left + plot.width * hi / (n - 1);
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    for (final s in series) {
      if (hi >= s.samples.length) continue;
      final p = point(hi, s.samples[hi].value);
      canvas.drawCircle(p, 5, Paint()..color = s.color);
      canvas.drawCircle(p, 2.4, Paint()..color = Colors.white);
    }

    const boxW = 132.0;
    final boxH = 22.0 + series.length * 16.0;
    var left = x + 10;
    if (left + boxW > size.width) left = x - boxW - 10;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left.clamp(0.0, size.width - boxW), plot.top, boxW, boxH),
      const Radius.circular(10),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xE60F172A));
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    _text(
      canvas,
      formatTooltipTime(series.first.samples[hi].time, range),
      Offset(box.left + 10, box.top + 12),
      color: SysDashColors.textSecondary,
      size: 10,
    );
    for (var s = 0; s < series.length; s++) {
      final data = series[s];
      if (hi >= data.samples.length) continue;
      final y = box.top + 28 + s * 16;
      canvas.drawCircle(Offset(box.left + 14, y), 3.5, Paint()..color = data.color);
      _text(
        canvas,
        '${data.label}: ${formatMetric(data.samples[hi].value, unit)}',
        Offset(box.left + 22, y),
        color: SysDashColors.textPrimary,
        size: 10.5,
        weight: FontWeight.w700,
      );
    }
  }

  // Live buffers are mutated in place, so always repaint (cheap).
  @override
  bool shouldRepaint(covariant _TimeSeriesPainter oldDelegate) => true;
}

// =============================================================================
// Glass chart card: header + range selector + chart + stats
// =============================================================================
class MetricLine {
  final MetricKey key;
  final String label;
  final Color color;
  const MetricLine(this.key, this.label, this.color);
}

class MetricChartCard extends StatefulWidget {
  final TelemetryService service;
  final ServerNode node;
  final String title;
  final IconData icon;
  final Color accent;
  final List<MetricLine> lines;
  final String unit;
  final double? fixedMax;
  final double chartHeight;

  const MetricChartCard({
    super.key,
    required this.service,
    required this.node,
    required this.title,
    required this.icon,
    required this.accent,
    required this.lines,
    required this.unit,
    this.fixedMax,
    this.chartHeight = 170,
  });

  @override
  State<MetricChartCard> createState() => _MetricChartCardState();
}

class _MetricChartCardState extends State<MetricChartCard> {
  TimeRange _range = TimeRange.live;

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    final series = [
      for (final l in widget.lines)
        ChartSeries(
          label: l.label,
          color: l.color,
          samples: widget.service.series(widget.node, l.key, _range),
        ),
    ];
    final primary = series.isNotEmpty ? series.first.samples : const <TimedSample>[];
    final values = primary.map((e) => e.value);
    final fallbackVal = widget.lines.isNotEmpty ? widget.node.value(widget.lines.first.key) : 0.0;
    final nowV = primary.isNotEmpty ? primary.last.value : fallbackVal;
    final avgV = primary.isNotEmpty ? values.reduce((a, b) => a + b) / primary.length : nowV;
    final peakV = primary.isNotEmpty ? values.reduce(math.max) : nowV;

    return GlassCard(
      glowColor: widget.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: widget.icon, color: widget.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SysDashColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.timeRange(_range),
                      style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                formatMetric(nowV, widget.unit),
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TimeRangeSelector(
            selected: _range,
            accent: widget.accent,
            onChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 14),
          TimeSeriesChart(
            series: series,
            range: _range,
            unit: widget.unit,
            fixedMax: widget.fixedMax,
            height: widget.chartHeight,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (series.length > 1)
                for (final s in series) _Legend(color: s.color, label: s.label),
              _StatChip(label: strings.now, value: formatMetric(nowV, widget.unit)),
              _StatChip(label: strings.avg, value: formatMetric(avgV, widget.unit)),
              _StatChip(label: strings.peak, value: formatMetric(peakV, widget.unit)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11.5)),
      const SizedBox(width: 4),
    ],
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: SysDashColors.glassBorderSubtle),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: SysDashColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Small sparkline used in compact overview tiles.
class Sparkline extends StatelessWidget {
  final List<TimedSample> samples;
  final Color color;
  final double max;

  const Sparkline({super.key, required this.samples, required this.color, this.max = 100});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SparklinePainter(samples, color, max),
    size: Size.infinite,
  );
}

class _SparklinePainter extends CustomPainter {
  final List<TimedSample> samples;
  final Color color;
  final double max;
  _SparklinePainter(this.samples, this.color, this.max);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final n = samples.length;
    final pts = [
      for (var i = 0; i < n; i++)
        Offset(
          size.width * i / (n - 1),
          size.height - (samples[i].value / max).clamp(0.02, 1.0) * (size.height - 4) - 2,
        ),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < n - 1; i++) {
      final cx = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(cx, pts[i].dy, cx, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

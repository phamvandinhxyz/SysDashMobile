import '../models/server_models.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Axis label for a timestamp, granularity depends on the selected range.
String formatAxisTime(DateTime t, TimeRange range) => switch (range) {
  TimeRange.live => '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}',
  TimeRange.hour1 || TimeRange.hour12 || TimeRange.hour24 =>
    '${_two(t.hour)}:${_two(t.minute)}',
  TimeRange.week1 || TimeRange.day30 => '${_two(t.day)}/${_two(t.month)}',
};

/// Full timestamp used inside chart tooltips.
String formatTooltipTime(DateTime t, TimeRange range) => switch (range) {
  TimeRange.live => '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}',
  TimeRange.hour1 || TimeRange.hour12 || TimeRange.hour24 =>
    '${_two(t.hour)}:${_two(t.minute)}  ${_two(t.day)}/${_two(t.month)}',
  TimeRange.week1 || TimeRange.day30 =>
    '${_two(t.day)}/${_two(t.month)}  ${_two(t.hour)}:${_two(t.minute)}',
};

/// Formats a metric value with its unit.
String formatMetric(double v, String unit, {bool compact = false}) {
  switch (unit) {
    case 'Mbps':
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(compact ? 1 : 2)} Gbps';
      return '${v.toStringAsFixed(compact || v >= 100 ? 0 : 1)} Mbps';
    case 'MB/s':
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} GB/s';
      return '${v.toStringAsFixed(compact || v >= 100 ? 0 : 1)} MB/s';
    case '%':
      return '${v.toStringAsFixed(compact || v >= 10 ? 0 : 1)}%';
    case '°C':
      return '${v.toStringAsFixed(compact ? 0 : 1)}°C';
    default:
      return '${v.toStringAsFixed(compact ? 0 : 1)} $unit';
  }
}

String formatGb(double gb) {
  if (gb >= 1024) return '${(gb / 1024).toStringAsFixed(2)} TB';
  if (gb < 1) return '${(gb * 1024).toStringAsFixed(0)} MB';
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}

String formatMb(double mb) {
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  return '${mb.toStringAsFixed(0)} MB';
}

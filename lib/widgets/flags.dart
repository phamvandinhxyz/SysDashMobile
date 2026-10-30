import 'dart:math' as math;

import 'package:flutter/material.dart';

/// National flag of Vietnam drawn on Canvas:
/// red field (#DA251D) + centred five-pointed yellow star (#FFFF00).
class VietnamFlagPainter extends CustomPainter {
  const VietnamFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFDA251D));

    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.height * 0.34;
    final inner = outer * 0.381966; // golden-ratio inner vertex

    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFFF00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Union Jack drawn on Canvas: blue field (#012169), white/red saltires and
/// St George's cross (#C8102E) with white fimbriation.
class UkFlagPainter extends CustomPainter {
  const UkFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final c = Offset(w / 2, h / 2);

    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF012169));

    final whiteDiag = Paint()
      ..color = Colors.white
      ..strokeWidth = h * 0.22;
    final redDiag = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = h * 0.09;
    for (final paint in [whiteDiag, redDiag]) {
      canvas.drawLine(Offset.zero, Offset(w, h), paint);
      canvas.drawLine(Offset(0, h), Offset(w, 0), paint);
    }

    final white = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromCenter(center: c, width: w, height: h * 0.34), white);
    canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.24, height: h), white);

    final red = Paint()..color = const Color(0xFFC8102E);
    canvas.drawRect(Rect.fromCenter(center: c, width: w, height: h * 0.20), red);
    canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.14, height: h), red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// SVG equivalents for use with `flutter_svg` (`SvgPicture.string`).
class FlagSvgStrings {
  FlagSvgStrings._();

  static const String vietnam = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20">
  <rect width="30" height="20" fill="#DA251D" rx="2"/>
  <polygon fill="#FFFF00" points="15,4 16.76,9.42 22.46,9.42 17.85,12.77 19.61,18.19 15,14.84 10.39,18.19 12.15,12.77 7.54,9.42 13.24,9.42"/>
</svg>
''';

  static const String uk = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 30">
  <clipPath id="c"><rect width="60" height="30" rx="3"/></clipPath>
  <g clip-path="url(#c)">
    <rect width="60" height="30" fill="#012169"/>
    <path d="M0,0 L60,30 M60,0 L0,30" stroke="#FFFFFF" stroke-width="6"/>
    <path d="M0,0 L60,30 M60,0 L0,30" stroke="#C8102E" stroke-width="2.6"/>
    <path d="M30,0 V30 M0,15 H60" stroke="#FFFFFF" stroke-width="10"/>
    <path d="M30,0 V30 M0,15 H60" stroke="#C8102E" stroke-width="6"/>
  </g>
</svg>
''';
}

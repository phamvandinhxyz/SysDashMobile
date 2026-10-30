// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  const int size = 1024;
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // 1. Generate Full App Icon with Pure White Background (for iOS, Legacy Android & Stores)
  final fullIcon = _createFullIcon(size);
  final fullBytes = img.encodePng(fullIcon);
  File('assets/icon/app_icon.png').writeAsBytesSync(fullBytes);
  print('Successfully generated assets/icon/app_icon.png (${fullBytes.length} bytes)');

  // 2. Generate Adaptive Foreground Icon with Transparent Background
  final fgIcon = _createAdaptiveForeground(size);
  final fgBytes = img.encodePng(fgIcon);
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(fgBytes);
  print('Successfully generated assets/icon/app_icon_foreground.png (${fgBytes.length} bytes)');

  // 3. Generate In-App Transparent Icon (for Login Screen & Top Bar)
  final inAppIcon = _createTransparentInAppIcon(size);
  final inAppBytes = img.encodePng(inAppIcon);
  File('assets/icon/app_icon_transparent.png').writeAsBytesSync(inAppBytes);
  print('Successfully generated assets/icon/app_icon_transparent.png (${inAppBytes.length} bytes)');
}

img.Image _createFullIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  // Background: Crisp Pure White (#FFFFFF)
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      image.setPixelRgba(x, y, 255, 255, 255, 255);
    }
  }

  // Draw 3 Server Blades with soft drop shadow
  _renderServerRack(image, center: size / 2, scale: 1.0, isTransparentBg: false);

  return image;
}

img.Image _createAdaptiveForeground(int size) {
  // Transparent base
  final image = img.Image(width: size, height: size, numChannels: 4);

  // Draw 3 Server Blades scaled safely within Android adaptive mask
  _renderServerRack(image, center: size / 2, scale: 0.88, isTransparentBg: true);

  return image;
}

img.Image _createTransparentInAppIcon(int size) {
  // 100% transparent base for in-app widgets (Login screen, Top bar)
  final image = img.Image(width: size, height: size, numChannels: 4);

  // Draw 3 Server Blades at prominent scale
  _renderServerRack(image, center: size / 2, scale: 1.25, isTransparentBg: true);

  return image;
}

void _renderServerRack(
  img.Image image, {
  required double center,
  required double scale,
  required bool isTransparentBg,
}) {
  final bladeWidth = (640 * scale).round();
  final bladeHeight = (136 * scale).round();
  final spacing = (42 * scale).round();
  final totalHeight = bladeHeight * 3 + spacing * 2;

  final startY = (center - totalHeight / 2).round();
  final bladeLeft = (center - bladeWidth / 2).round();

  final blade1Top = startY;
  final blade2Top = startY + bladeHeight + spacing;
  final blade3Top = startY + (bladeHeight + spacing) * 2;

  // Primary LED colors for the 3 server blades
  // Blade 1: Emerald (#10B981) - System Active & Operational
  final blade1Color = img.ColorRgba8(16, 185, 129, 255);
  // Blade 2: Cyan (#06B6D4) - Realtime Telemetry & Data Stream
  final blade2Color = img.ColorRgba8(6, 182, 212, 255);
  // Blade 3: Violet (#8B5CF6) - Security Core & Matrix
  final blade3Color = img.ColorRgba8(139, 92, 246, 255);

  // 1. Draw Drop Shadows for all 3 blades first
  _drawBladeShadow(image, left: bladeLeft, top: blade1Top, width: bladeWidth, height: bladeHeight, scale: scale);
  _drawBladeShadow(image, left: bladeLeft, top: blade2Top, width: bladeWidth, height: bladeHeight, scale: scale);
  _drawBladeShadow(image, left: bladeLeft, top: blade3Top, width: bladeWidth, height: bladeHeight, scale: scale);

  // 2. Draw the 3 Server Blades
  _drawServerBlade(
    image,
    left: bladeLeft,
    top: blade1Top,
    width: bladeWidth,
    height: bladeHeight,
    scale: scale,
    primaryLedColor: blade1Color,
    bladeIndex: 1,
  );

  _drawServerBlade(
    image,
    left: bladeLeft,
    top: blade2Top,
    width: bladeWidth,
    height: bladeHeight,
    scale: scale,
    primaryLedColor: blade2Color,
    bladeIndex: 2,
  );

  _drawServerBlade(
    image,
    left: bladeLeft,
    top: blade3Top,
    width: bladeWidth,
    height: bladeHeight,
    scale: scale,
    primaryLedColor: blade3Color,
    bladeIndex: 3,
  );
}

void _drawBladeShadow(
  img.Image image, {
  required int left,
  required int top,
  required int width,
  required int height,
  required double scale,
}) {
  final shadowOffsetY = (14 * scale).round();
  final shadowBlur = (16 * scale).round();
  final shadowRadius = (28 * scale).round();

  final sLeft = left;
  final sTop = top + shadowOffsetY;
  final sRight = sLeft + width;
  final sBottom = sTop + height;

  for (int y = sTop - shadowBlur; y < sBottom + shadowBlur; y++) {
    for (int x = sLeft - shadowBlur; x < sRight + shadowBlur; x++) {
      final dist = _distToRoundedRect(x, y, sLeft, sTop, sRight, sBottom, shadowRadius);
      if (dist < shadowBlur) {
        final factor = (1.0 - (dist / shadowBlur)).clamp(0.0, 1.0);
        final alpha = (math.pow(factor, 1.8) * 55).round().clamp(0, 255);
        if (alpha > 0) {
          _blendPixel(image, x, y, img.ColorRgba8(15, 23, 42, alpha));
        }
      }
    }
  }
}

void _drawServerBlade(
  img.Image image, {
  required int left,
  required int top,
  required int width,
  required int height,
  required double scale,
  required img.Color primaryLedColor,
  required int bladeIndex,
}) {
  final right = left + width;
  final bottom = top + height;
  final radius = (26 * scale).round().clamp(12, 32);

  // 1. Blade Body: Dark Navy Slate (#0F172A -> #1E293B vertical gradient)
  for (int y = top; y < bottom; y++) {
    final t = (y - top) / height;
    final r = (30 * (1 - t) + 15 * t).round();
    final g = (41 * (1 - t) + 23 * t).round();
    final b = (59 * (1 - t) + 42 * t).round();

    for (int x = left; x < right; x++) {
      final dist = _distToRoundedRect(x, y, left, top, right, bottom, radius);
      if (dist <= 0) {
        if (dist >= -3) {
          // Subtle tech border
          _blendPixel(image, x, y, img.ColorRgba8(71, 85, 105, 220)); // Slate-600
        } else {
          // Chassis fill
          _blendPixel(image, x, y, img.ColorRgba8(r, g, b, 255));
        }
      }
    }
  }

  // 2. Specular sheen at top inner edge
  final sheenHeight = (8 * scale).round().clamp(4, 12);
  for (int y = top + 3; y < top + 3 + sheenHeight; y++) {
    final tY = (y - (top + 3)) / sheenHeight;
    final alphaY = (1.0 - tY);
    for (int x = left + radius; x < right - radius; x++) {
      final tX = (x - (left + radius)) / (width - 2 * radius);
      final alphaX = math.sin(tX * math.pi);
      final alpha = (alphaX * alphaY * 110).round().clamp(0, 255);
      if (alpha > 0) {
        _blendPixel(image, x, y, img.ColorRgba8(255, 255, 255, alpha));
      }
    }
  }

  // 3. Left Rack Mounting Ear / Handle Accent
  final handleLeft = left + (32 * scale).round();
  final handleWidth = (14 * scale).round().clamp(8, 20);
  final handleTop = top + (26 * scale).round();
  final handleBottom = bottom - (26 * scale).round();
  final handleRadius = (6 * scale).round().clamp(3, 8);

  for (int y = handleTop; y < handleBottom; y++) {
    for (int x = handleLeft; x < handleLeft + handleWidth; x++) {
      final dist = _distToRoundedRect(x, y, handleLeft, handleTop, handleLeft + handleWidth, handleBottom, handleRadius);
      if (dist <= 0) {
        _blendPixel(image, x, y, img.ColorRgba8(51, 65, 85, 240)); // Slate-700
      }
    }
  }

  // 4. Server Ventilation Grille (Horizontal sleek slots)
  final grilleStartX = left + (74 * scale).round();
  final grilleEndX = right - (200 * scale).round();
  final grilleSlotHeight = (7 * scale).round().clamp(4, 10);
  final grilleSlotSpacing = (16 * scale).round().clamp(10, 22);

  final grilleStartY = top + (34 * scale).round();
  final grilleEndY = bottom - (34 * scale).round();

  for (int y = grilleStartY; y <= grilleEndY; y += grilleSlotSpacing) {
    for (int slotY = y; slotY < y + grilleSlotHeight && slotY < bottom - 12; slotY++) {
      for (int x = grilleStartX; x < grilleEndX; x++) {
        // Deep inset slot
        _blendPixel(image, x, slotY, img.ColorRgba8(8, 12, 22, 255));
        // Lower slot rim highlight
        if (slotY == y + grilleSlotHeight - 1) {
          _blendPixel(image, x, slotY, img.ColorRgba8(71, 85, 105, 120));
        }
      }
    }
  }

  // 5. LED Status Cluster on the Right Side
  final ledCenterY = (top + bottom) ~/ 2;
  final mainLedRadius = (14 * scale).round().clamp(8, 18);
  final subLedRadius = (8 * scale).round().clamp(5, 11);

  // Main Feature Status LED (Glow + Solid Core)
  final mainLedX = right - (136 * scale).round();
  _drawIlluminatedLed(image, mainLedX, ledCenterY, mainLedRadius, primaryLedColor);

  // Secondary Activity LEDs
  final sub1LedX = right - (86 * scale).round();
  final sub2LedX = right - (46 * scale).round();

  // Activity LED colors based on blade
  final sub1Color = bladeIndex == 1
      ? img.ColorRgba8(6, 182, 212, 255) // Cyan
      : bladeIndex == 2
          ? img.ColorRgba8(16, 185, 129, 255) // Green
          : img.ColorRgba8(6, 182, 212, 255); // Cyan

  final sub2Color = bladeIndex == 3
      ? img.ColorRgba8(16, 185, 129, 255) // Green
      : img.ColorRgba8(148, 163, 184, 255); // Slate Silver

  _drawIlluminatedLed(image, sub1LedX, ledCenterY, subLedRadius, sub1Color);
  _drawIlluminatedLed(image, sub2LedX, ledCenterY, subLedRadius, sub2Color);
}

void _drawIlluminatedLed(img.Image image, int cx, int cy, int radius, img.Color color) {
  final r = color.r.toInt();
  final g = color.g.toInt();
  final b = color.b.toInt();

  // Outer ambient glow ring
  final glowRadius = (radius * 2.4).round();
  for (int dy = -glowRadius; dy <= glowRadius; dy++) {
    for (int dx = -glowRadius; dx <= glowRadius; dx++) {
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= radius) {
        // Solid core with bright center
        final coreDist = dist / radius;
        if (coreDist < 0.45) {
          // Specular white-hot center
          final t = (1.0 - (coreDist / 0.45));
          final cr = (r * (1 - t) + 255 * t).round().clamp(0, 255);
          final cg = (g * (1 - t) + 255 * t).round().clamp(0, 255);
          final cb = (b * (1 - t) + 255 * t).round().clamp(0, 255);
          _blendPixel(image, cx + dx, cy + dy, img.ColorRgba8(cr, cg, cb, 255));
        } else {
          image.setPixelRgba(cx + dx, cy + dy, r, g, b, 255);
        }
      } else if (dist <= glowRadius) {
        // Radial falloff glow
        final factor = 1.0 - (dist - radius) / (glowRadius - radius);
        final alpha = (math.pow(factor, 1.6) * 160).round().clamp(0, 255);
        if (alpha > 0) {
          _blendPixel(image, cx + dx, cy + dy, img.ColorRgba8(r, g, b, alpha));
        }
      }
    }
  }
}

double _distToRoundedRect(int px, int py, int left, int top, int right, int bottom, int r) {
  final cx = (px < left + r)
      ? left + r
      : (px > right - r)
          ? right - r
          : px;
  final cy = (py < top + r)
      ? top + r
      : (py > bottom - r)
          ? bottom - r
          : py;

  final dx = (px - cx).toDouble();
  final dy = (py - cy).toDouble();
  final distToCorner = math.sqrt(dx * dx + dy * dy);

  if (px >= left + r && px <= right - r && py >= top && py <= bottom) {
    return -1.0;
  }
  if (py >= top + r && py <= bottom - r && px >= left && px <= right) {
    return -1.0;
  }

  return distToCorner - r;
}

void _blendPixel(img.Image image, int x, int y, img.Color color) {
  if (x < 0 || x >= image.width || y < 0 || y >= image.height) return;

  final srcA = color.a / 255.0;
  if (srcA <= 0) return;

  final dst = image.getPixel(x, y);
  final dstA = dst.a / 255.0;

  final outA = srcA + dstA * (1.0 - srcA);
  if (outA <= 0) return;

  final outR = ((color.r * srcA + dst.r * dstA * (1.0 - srcA)) / outA).round().clamp(0, 255);
  final outG = ((color.g * srcA + dst.g * dstA * (1.0 - srcA)) / outA).round().clamp(0, 255);
  final outB = ((color.b * srcA + dst.b * dstA * (1.0 - srcA)) / outA).round().clamp(0, 255);
  final finalA = (outA * 255).round().clamp(0, 255);

  image.setPixelRgba(x, y, outR, outG, outB, finalA);
}

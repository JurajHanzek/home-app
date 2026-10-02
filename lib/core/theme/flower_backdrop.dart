import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original vector botanicals: no remote assets, image downloads or hit targets.
/// A short entrance settles into a still background to avoid a permanent ticker.
class FlowerBackdrop extends StatefulWidget {
  const FlowerBackdrop({required this.child, super.key});
  final Widget child;

  @override
  State<FlowerBackdrop> createState() => _FlowerBackdropState();
}

class _FlowerBackdropState extends State<FlowerBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bloom.value = 1;
    } else if (!_bloom.isAnimating && _bloom.value == 0) {
      _bloom.forward();
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _BotanicalPainter(_bloom)),
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class _BotanicalPainter extends CustomPainter {
  _BotanicalPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD4E9DB), Color(0xFFEDF3DE), Color(0xFFDDEAC7)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    final t = Curves.easeOutCubic.transform(animation.value);
    final scale = (size.width / 420).clamp(0.75, 1.35);
    canvas.save();
    canvas.clipRect(rect);
    // Corner arrangements keep the central reading column quiet.
    canvas.save();
    canvas.translate(size.width + 15, size.height - 32 + (1 - t) * 24);
    canvas.scale(scale * (0.94 + 0.06 * t));
    canvas.rotate(-0.06 * (1 - t));
    _bouquet(canvas, 0.82 * t);
    canvas.restore();
    canvas.save();
    canvas.translate(-20, size.height * 0.62 + (1 - t) * 18);
    canvas.scale(-scale * 0.7, scale * 0.7);
    canvas.rotate(-0.2);
    _bouquet(canvas, 0.55 * t);
    canvas.restore();
    canvas.save();
    canvas.translate(size.width - 14, 88);
    canvas.scale(scale * 0.65);
    _sprig(canvas, const Offset(0, 95), const Offset(-100, -38), 0.4 * t);
    _flower(
      canvas,
      const Offset(-32, 13),
      20,
      const Color(0xFFE1D9E7),
      0.6 * t,
    );
    _flower(
      canvas,
      const Offset(-80, 65),
      24,
      const Color(0xFFF4F5D0),
      0.6 * t,
    );
    _flower(
      canvas,
      const Offset(-15, 112),
      16,
      const Color(0xFFE9D8E8),
      0.65 * t,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-14, size.height - 75);
    canvas.scale(-scale * 0.65, scale * 0.65);
    _bouquet(canvas, 0.65 * t);
    canvas.restore();
    canvas.restore();
  }

  void _bouquet(Canvas canvas, double opacity) {
    _sprig(canvas, const Offset(0, 0), const Offset(-205, -56), opacity);
    _sprig(canvas, const Offset(0, 0), const Offset(-145, -180), opacity);
    _sprig(canvas, const Offset(0, 0), const Offset(-38, -245), opacity);
    _sprig(canvas, const Offset(-5, 0), const Offset(-225, 12), opacity * 0.75);
    _flower(
      canvas,
      const Offset(-82, -76),
      43,
      const Color(0xFFF7F6D9),
      opacity,
    );
    _flower(
      canvas,
      const Offset(-153, -43),
      29,
      const Color(0xFFE5DCEC),
      opacity,
    );
    _flower(
      canvas,
      const Offset(-43, -157),
      24,
      const Color(0xFFFFFCEF),
      opacity,
    );
    _flower(
      canvas,
      const Offset(-180, -106),
      16,
      const Color(0xFFEED8DB),
      opacity * 0.8,
    );
    for (var i = 0; i < 5; i++) {
      final point = Offset(-24.0 - i * 12, -197.0 + i * 11);
      _flower(canvas, point, 6, const Color(0xFFFFFCEF), opacity);
    }
  }

  void _sprig(Canvas canvas, Offset start, Offset end, double opacity) {
    final stem = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(end.dx * 0.2, end.dy * 0.7, end.dx, end.dy);
    canvas.drawPath(
      stem,
      Paint()
        ..color = const Color(0xFF486B48).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    final metric = stem.computeMetrics().first;
    for (var i = 1; i <= 6; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / 7)!;
      for (final side in [-1, 1]) {
        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        canvas.rotate(tangent.angle + side * 0.7);
        final length = 34.0 - i * 2.3;
        final leaf = Path()
          ..moveTo(0, 0)
          ..cubicTo(
            length * 0.15,
            -length * 0.5,
            length * 0.8,
            -length * 0.4,
            length,
            0,
          )
          ..cubicTo(
            length * 0.65,
            length * 0.36,
            length * 0.2,
            length * 0.3,
            0,
            0,
          );
        canvas.drawPath(
          leaf,
          Paint()
            ..shader = LinearGradient(
              colors: [
                const Color(0xFF426848).withValues(alpha: opacity),
                const Color(0xFF9DBA7E).withValues(alpha: opacity),
              ],
            ).createShader(Rect.fromLTWH(0, -length / 2, length, length)),
        );
        canvas.drawLine(
          Offset.zero,
          Offset(length * 0.85, 0),
          Paint()
            ..color = const Color(0xFFE6EDCC).withValues(alpha: opacity * 0.65)
            ..strokeWidth = 0.7,
        );
        canvas.restore();
      }
    }
  }

  void _flower(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var layer = 0; layer < 2; layer++) {
      final r = radius * (layer == 0 ? 1 : 0.68);
      for (var i = 0; i < 7; i++) {
        canvas.save();
        canvas.rotate(i * math.pi * 2 / 7 + layer * 0.4);
        final petal = Path()
          ..moveTo(0, 3)
          ..cubicTo(-r * 0.7, -r * 0.3, -r * 0.55, -r * 1.12, 0, -r)
          ..cubicTo(r * 0.55, -r * 1.12, r * 0.7, -r * 0.3, 0, 3);
        canvas.drawPath(
          petal,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 0.7),
              radius: 1,
              colors: [
                const Color(0xFFC4CEAA).withValues(alpha: opacity),
                color.withValues(alpha: opacity),
              ],
            ).createShader(Rect.fromLTWH(-r, -r, r * 2, r * 1.2)),
        );
        canvas.drawPath(
          petal,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = const Color(0xFF718762).withValues(alpha: opacity * 0.35),
        );
        canvas.restore();
      }
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.16,
      Paint()..color = const Color(0xFF73834C).withValues(alpha: opacity),
    );
    for (var i = 0; i < 9; i++) {
      final angle = i * math.pi * 2 / 9;
      canvas.drawCircle(
        Offset(math.cos(angle), math.sin(angle)) * radius * 0.2,
        math.max(0.8, radius * 0.035),
        Paint()..color = const Color(0xFFE8DBA1).withValues(alpha: opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BotanicalPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

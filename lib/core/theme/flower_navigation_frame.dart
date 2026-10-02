import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative only: navigation owns all gestures and accessibility semantics.
class FlowerNavigationFrame extends StatefulWidget {
  const FlowerNavigationFrame({
    required this.enabled,
    required this.selectedIndex,
    required this.child,
    super.key,
  });

  final bool enabled;
  final int selectedIndex;
  final Widget child;

  @override
  State<FlowerNavigationFrame> createState() => _FlowerNavigationFrameState();
}

class _FlowerNavigationFrameState extends State<FlowerNavigationFrame>
    with SingleTickerProviderStateMixin {
  late final _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  void _animate() {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _bloom.value = 1;
    } else {
      _bloom.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  @override
  void didUpdateWidget(FlowerNavigationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.selectedIndex != widget.selectedIndex) {
      _animate();
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 4),
            child: widget.child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _FlowerRimPainter(_bloom)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerRimPainter extends CustomPainter {
  _FlowerRimPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(animation.value);
    final sway = math.sin(animation.value * math.pi * 2) * (1 - t);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Two vines travel along the upper rim and curl down the outer edges.
    for (final right in [false, true]) {
      canvas.save();
      if (right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final half = size.width / 2;
      final vine = Path()
        ..moveTo(6, size.height - 10)
        ..cubicTo(0, size.height * 0.55, 5, 30, 17, 18)
        ..cubicTo(35, -1, half * 0.65, 22, half, 9);
      canvas.drawPath(
        vine,
        Paint()
          ..color = const Color(0xFF527C45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      final metric = vine.computeMetrics().first;
      for (var i = 1; i <= 9; i++) {
        final tangent = metric.getTangentForOffset(metric.length * i / 10)!;
        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        canvas.rotate(tangent.angle + (i.isEven ? 0.7 : -0.7) + sway * 0.12);
        final length = (i < 4 ? 8.0 : 11.0) * (0.85 + 0.15 * t);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(length * 0.45, -length * 0.75, length, 0)
          ..quadraticBezierTo(length * 0.45, length * 0.45, 0, 0);
        canvas.drawPath(
          leaf,
          Paint()
            ..color = i.isEven
                ? const Color(0xFF73975A)
                : const Color(0xFF426D42),
        );
        canvas.restore();
      }
      _flower(canvas, Offset(27, 15), 10.5, t, const Color(0xFFE6D6E9));
      _flower(canvas, Offset(half * 0.6, 11), 7.5, t, const Color(0xFFFFF3CA));
      _flower(
        canvas,
        Offset(7, size.height * 0.64),
        5.5,
        t,
        const Color(0xFFF2DFE4),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _flower(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.7 + 0.3 * t);
    canvas.rotate((1 - t) * 0.35);
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      final petal = Path()
        ..moveTo(0, 1)
        ..cubicTo(
          -radius * 0.6,
          -radius * 0.3,
          -radius * 0.6,
          -radius,
          0,
          -radius,
        )
        ..cubicTo(radius * 0.6, -radius, radius * 0.6, -radius * 0.3, 0, 1);
      canvas.drawPath(petal, Paint()..color = color);
      canvas.drawPath(
        petal,
        Paint()
          ..color = const Color(0xFF80936B).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.22,
      Paint()..color = const Color(0xFF8D9A50),
    );
    canvas.drawCircle(
      const Offset(-0.5, -0.5),
      radius * 0.1,
      Paint()..color = const Color(0xFFF1D883),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerRimPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

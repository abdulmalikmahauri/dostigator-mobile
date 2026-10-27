import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Кольцо прогресса (раздел 10.6). Одно крупное кольцо на экран.
/// Анимируется при появлении, уважает reduced motion, озвучивается
/// текстовым значением для доступности.
class DProgressRing extends StatelessWidget {
  const DProgressRing({
    super.key,
    required this.percent,
    this.size = 116,
    this.stroke = 9,
    this.center,
    this.color,
  });

  /// 0–100.
  final int percent;
  final double size;
  final double stroke;
  final Widget? center;

  /// null — акцент текущей темы.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final target = (percent.clamp(0, 100)) / 100.0;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final palette = DColors.of(context);
    final ringColor = color ?? palette.accent;

    return Semantics(
      label: 'Прогресс $percent процентов',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? target : 0, end: target),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            value: value,
            stroke: stroke,
            color: ringColor,
            trackColor: palette.surface3,
          ),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: center),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = stroke / 2;
    final arcRect = rect.deflate(inset);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    if (value <= 0) return;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}

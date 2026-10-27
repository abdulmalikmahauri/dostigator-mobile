import 'package:flutter/material.dart';

/// Значок Instagram: скруглённый квадрат, кольцо объектива и точка
/// вспышки. Рисуется штрихом в цвете текста, как и прочие значки
/// приложения, — фирменный градиент здесь был бы чужеродным пятном.
class DInstagramGlyph extends StatelessWidget {
  const DInstagramGlyph({super.key, this.size = 22, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _InstagramPainter(color),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  _InstagramPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(stroke, stroke, s - stroke * 2, s - stroke * 2),
      Radius.circular(s * 0.28),
    );
    canvas.drawRRect(frame, paint);

    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.21, paint);

    canvas.drawCircle(
      Offset(s * 0.72, s * 0.28),
      stroke * 0.7,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_InstagramPainter old) => old.color != color;
}

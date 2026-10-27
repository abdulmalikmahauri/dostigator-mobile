import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Фирменный фон по разделу 7 спецификации: тёмная база, поверх — pattern 1
/// с едва заметными штрихами, и один крупный фрагмент фирменной геометрии,
/// частично выходящий за правую границу. Никаких декоративных цифр.
class DBackground extends StatelessWidget {
  const DBackground({
    super.key,
    required this.child,
    this.pattern = true,
    this.wedge = false,
    this.wedgeTop = 260,
  });

  final Widget child;
  final bool pattern;

  /// Крупный зелёный клин у правого края. Включается точечно —
  /// на корневых вкладках, не на каждом вторичном экране.
  final bool wedge;
  final double wedgeTop;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.background),
        if (pattern)
          Positioned.fill(
            child: IgnorePointer(
              // Штрихи паттерна уже приглушены в самом файле брендбука —
              // дополнительная прозрачность не нужна. Файл монохромный,
              // поэтому в светлой теме его можно перекрасить, не рисуя
              // второй вариант паттерна.
              child: Image.asset(
                'assets/brand/pattern.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                color: c.patternStroke,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        if (wedge)
          Positioned(
            top: wedgeTop,
            right: -36,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(150, 260),
                painter: _WedgePainter(c.accent),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// Фрагмент фирменной геометрии — нога знака Λ под углом бренда.
/// Это фоновая графика из брендбука, а не перерисовка логотипа.
class _WedgePainter extends CustomPainter {
  _WedgePainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withValues(alpha: 0.85);

    final w = size.width;
    final h = size.height;

    // Широкая диагональная полоса, уходящая за правый край
    final leg = Path()
      ..moveTo(w * 0.55, 0)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(w * 0.30, h * 0.28)
      ..lineTo(w * 0.30, 0)
      ..close();
    canvas.drawPath(leg, paint);

    // Узкий параллельный штрих ниже — как в раскладке паттерна
    final echo = Path()
      ..moveTo(w * 0.62, h * 0.66)
      ..lineTo(w, h * 0.98)
      ..lineTo(w, h * 1.0)
      ..lineTo(w * 0.62, h * 0.78)
      ..close();
    canvas.drawPath(echo, paint..color = accent.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_WedgePainter old) => old.accent != accent;
}

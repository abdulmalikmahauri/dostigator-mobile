import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Primary CTA (раздел 10.4): зелёный фон, тёмный текст, высота 54.
/// Во время загрузки — спиннер внутри кнопки и запрет повторного нажатия.
class DPrimaryButton extends StatelessWidget {
  const DPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.trailingArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Стрелка справа, как на референсах: «Заполнить →».
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: DColors.of(context).brandBlack,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (trailingArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'd_brand_card.dart';

/// Пустое состояние (раздел 31): спокойный текст и, при необходимости,
/// одно действие. Без иллюстративного шума.
class DEmptyState extends StatelessWidget {
  const DEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DText.of(context).cardTitle),
          if (message != null) ...[
            const SizedBox(height: DSpace.xs),
            Text(message!, style: DText.of(context).bodyMuted),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: DSpace.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Ошибка загрузки (раздел 32): не красить карточку в красный —
/// маленькая иконка, короткое сообщение, «Повторить».
class DErrorState extends StatelessWidget {
  const DErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: DColors.of(context).danger,
              ),
              const SizedBox(width: DSpace.sm),
              Expanded(child: Text(message, style: DText.of(context).body)),
            ],
          ),
          const SizedBox(height: DSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Повторить'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелет загрузки (раздел 33): пульсирующие плашки внутри карточек
/// вместо полноэкранного спиннера. При reduced motion пульсация замирает.
class DSkeleton extends StatefulWidget {
  const DSkeleton({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<DSkeleton> createState() => _DSkeletonState();
}

class _DSkeletonState extends State<DSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
    upperBound: 0.7,
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    }

    return FadeTransition(
      opacity: _c,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: DColors.of(context).surface3,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Типовой скелет карточки: заголовок и две строки.
class DSkeletonCard extends StatelessWidget {
  const DSkeletonCard({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSkeleton(height: 12, width: 110),
          const SizedBox(height: DSpace.md),
          for (var i = 0; i < lines; i++) ...[
            DSkeleton(height: 15, width: i.isEven ? double.infinity : 220),
            if (i < lines - 1) const SizedBox(height: DSpace.sm),
          ],
        ],
      ),
    );
  }
}

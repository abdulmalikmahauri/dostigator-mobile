import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'd_background.dart';

/// Каркас вторичного экрана: стрелка назад и заголовок, без нижней
/// навигации. Паттерн по умолчанию выключен — вторичные сценарии
/// (карта, check-in, формы) держим визуально тише корневых вкладок.
class DSubScaffold extends StatelessWidget {
  const DSubScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.children = const [],
    this.bottom,
    this.pattern = false,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Прижатая к низу панель — например, primary CTA формы.
  final Widget? bottom;
  final bool pattern;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        DSpace.page,
        DSpace.xs,
        DSpace.page,
        DSpace.xl,
      ),
      children: [
        if (subtitle != null) ...[
          Text(subtitle!, style: DText.of(context).bodyMuted),
          const SizedBox(height: DSpace.lg),
        ],
        ...children,
      ],
    );

    return Scaffold(
      backgroundColor: DColors.of(context).background,
      body: DBackground(
        pattern: pattern,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, DSpace.page, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 24),
                      color: DColors.of(context).textPrimary,
                      tooltip: 'Назад',
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        title,
                        style: DText.of(context).h2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: onRefresh == null
                    ? list
                    : RefreshIndicator(
                        color: DColors.of(context).accent,
                        backgroundColor: DColors.of(context).surface2,
                        onRefresh: onRefresh!,
                        child: list,
                      ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DSpace.page,
                    DSpace.sm,
                    DSpace.page,
                    DSpace.md,
                  ),
                  child: bottom!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

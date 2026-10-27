import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'd_background.dart';
import 'd_header.dart';

/// Каркас корневой вкладки (раздел 10.1): фирменный фон, header,
/// крупный заголовок раздела с подзаголовком и скролл содержимого.
/// Header не закреплён — уезжает вместе со страницей, как велит раздел 8.
class DAppScaffold extends StatelessWidget {
  const DAppScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.children = const [],
    this.onRefresh,
    this.wedge = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool wedge;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        DSpace.page,
        DSpace.sm,
        DSpace.page,
        DSpace.xl,
      ),
      children: [
        const DHeader(),
        const SizedBox(height: DSpace.xl),
        Text(title, style: DText.of(context).display),
        if (subtitle != null) ...[
          const SizedBox(height: DSpace.xs),
          Text(subtitle!, style: DText.of(context).bodyMuted),
        ],
        const SizedBox(height: DSpace.lg),
        ...children,
      ],
    );

    return DBackground(
      wedge: wedge,
      // Каркас вкладки самодостаточен: Material нужен InkWell-ам
      // содержимого и header, независимо от того, есть ли Scaffold выше
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: onRefresh == null
              ? list
              : RefreshIndicator(
                  color: DColors.of(context).accent,
                  backgroundColor: DColors.of(context).surface2,
                  onRefresh: onRefresh!,
                  child: list,
                ),
        ),
      ),
    );
  }
}

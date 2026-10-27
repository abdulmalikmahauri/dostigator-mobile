import 'package:flutter/material.dart';

import '../design/spacing.dart';
import 'd_brand_card.dart';

/// Карточка-контейнер для списочных блоков: строки с тонкими разделителями.
class DRowsCard extends StatelessWidget {
  const DRowsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.lg,
        vertical: DSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

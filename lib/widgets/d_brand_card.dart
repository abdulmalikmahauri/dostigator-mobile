import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';

/// Основная карточка (раздел 10.2): тонкий зелёный контур, без теней.
/// Карточки не должны выглядеть отдельными «плитками дашборда».
class DBrandCard extends StatelessWidget {
  const DBrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DSpace.card),
    this.background,
    this.borderColor,
    this.radius = DRadius.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// null — поверхность и контур карточки из палитры текущей темы.
  final Color? background;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? c.cardBorder, width: 1),
    );

    return Material(
      color: background ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              highlightColor: DColors.of(context).accentSoft,
              splashColor: Colors.transparent,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Строка списка (раздел 10.7): иконка или аватар слева, текст,
/// статус или значение справа, шеврон при наличии перехода.
class DListRow extends StatelessWidget {
  const DListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.sm),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: DSpace.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DText.of(
                    context,
                  ).body.copyWith(fontWeight: FontWeight.w500),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: DText.of(context).caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DSpace.sm),
            trailing!,
          ],
          if (chevron) ...[
            const SizedBox(width: DSpace.xs),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: DColors.of(context).textTertiary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    // Область нажатия — вся строка, не меньше 44 логических пикселей
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DRadius.input),
      highlightColor: DColors.of(context).accentSoft,
      splashColor: Colors.transparent,
      child: row,
    );
  }
}

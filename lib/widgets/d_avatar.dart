import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Аватар (раздел 10.8): фото, если оно есть; иначе инициалы
/// на тёмно-зелёном фоне с тонким зелёным контуром.
/// AI-портреты не генерируются — это прямой запрет спецификации.
class DUserAvatar extends StatelessWidget {
  const DUserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 38,
  });

  final String name;
  final String? photoUrl;
  final double size;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '·';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final url = photoUrl;

    final initials = Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: DText.family,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface3,
        border: Border.all(color: c.accentBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? initials
          : Image.network(
              url,
              fit: BoxFit.cover,
              // Пока фото не пришло и если не придёт вовсе — инициалы,
              // а не пустой круг: сломанная ссылка не должна ломать список
              errorBuilder: (_, _, _) => initials,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : initials,
            ),
    );
  }
}

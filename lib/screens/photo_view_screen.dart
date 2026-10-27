import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Фото резидента крупно: во весь экран, с увеличением двумя пальцами.
/// Открывается с аватара — своего в профиле и чужого в карточке каталога.
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.url, required this.name});

  final String url;

  /// Чьё это фото — заголовок экрана.
  final String name;

  static Future<void> open(
    BuildContext context, {
    required String url,
    required String name,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PhotoViewScreen(url: url, name: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, DSpace.page, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, size: 24),
                    color: c.textPrimary,
                    tooltip: 'Назад',
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      name,
                      style: t.h2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    semanticLabel: 'Фото: $name',
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : CircularProgressIndicator(color: c.accent),
                    errorBuilder: (_, _, _) => Padding(
                      padding: const EdgeInsets.all(DSpace.page),
                      child: Text(
                        'Фото не загрузилось. Проверьте интернет '
                        'и откройте его ещё раз.',
                        style: t.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Фото с мероприятия во весь экран: листаются пальцем,
/// каждое можно увеличить двумя пальцами.
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({
    super.key,
    required this.urls,
    required this.title,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final String title;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    required String title,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PhotoGalleryScreen(
          urls: urls,
          title: title,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);
    final total = widget.urls.length;

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
                      widget.title,
                      style: t.h2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DSpace.sm),
                  Text('${_index + 1} из $total', style: t.caption),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: total,
                // Увеличенное фото двигают пальцем — листать в это время нельзя
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (_, i) => _ZoomablePhoto(
                  url: widget.urls[i],
                  label: 'Фото ${i + 1} из $total',
                  onZoomChanged: (zoomed) {
                    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Одно фото с увеличением двумя пальцами. Сообщает, увеличено ли оно:
/// пока да, листание галереи выключено.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.label,
    required this.onZoomChanged,
  });

  final String url;
  final String label;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 5,
      onInteractionEnd: (_) =>
          widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
      child: Center(
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          semanticLabel: widget.label,
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
    );
  }
}

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Плеер VK Видео или Rutube на сайте — обычной вставкой iframe.
class VideoEmbed extends StatefulWidget {
  const VideoEmbed({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<VideoEmbed> createState() => _VideoEmbedState();
}

class _VideoEmbedState extends State<VideoEmbed>
    with AutomaticKeepAliveClientMixin {
  static int _next = 0;

  /// Прокрутили за край — плеер остаётся, видео не начинается сначала.
  @override
  bool get wantKeepAlive => true;

  /// Каждому плееру — своё имя: адрес видео у разных уроков разный.
  late final String _viewType = 'lesson-video-${_next++}';

  @override
  void initState() {
    super.initState();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final frame = web.HTMLIFrameElement()
        ..src = widget.url
        ..title = widget.title
        ..allow = 'autoplay; encrypted-media; fullscreen; picture-in-picture'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      frame.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%';

      return frame;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Semantics(
      label: 'Видео: ${widget.title}',
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}

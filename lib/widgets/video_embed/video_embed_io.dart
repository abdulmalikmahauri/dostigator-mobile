import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'video_hosts.dart';

/// Плеер VK Видео или Rutube во встроенном браузере. Уйти из плеера
/// на другой сайт нельзя: такие переходы открываются снаружи.
class VideoEmbed extends StatefulWidget {
  const VideoEmbed({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<VideoEmbed> createState() => _VideoEmbedState();
}

class _VideoEmbedState extends State<VideoEmbed>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;

  /// Плеер не пересоздаётся, когда его прокрутили за край экрана, —
  /// иначе видео начиналось бы сначала.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      // Плееры работают на JavaScript — без него видео не запустится
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            switch (VideoHosts.decide(
              request.url,
              isMainFrame: request.isMainFrame,
            )) {
              case NavDecision.allow:
                return NavigationDecision.navigate;
              case NavDecision.openOutside:
                launchUrl(
                  Uri.parse(request.url),
                  mode: LaunchMode.externalApplication,
                );
                return NavigationDecision.prevent;
              case NavDecision.block:
                return NavigationDecision.prevent;
            }
          },
        ),
      );

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      // Кнопка «на весь экран» в плеере: без этого на Android она молчит
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, onHidden) =>
            _showFullscreen(widget, onHidden),
        onHideCustomWidget: _hideFullscreen,
      );
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  bool _fullscreen = false;

  void _showFullscreen(Widget video, void Function() onHidden) {
    if (!mounted || _fullscreen) return;
    _fullscreen = true;

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(child: Center(child: video)),
            ),
          ),
        )
        .then((_) {
          // Закрыли кнопкой «Назад» — плееру надо сказать, что полный экран кончился
          if (_fullscreen) {
            _fullscreen = false;
            onHidden();
          }
        });
  }

  void _hideFullscreen() {
    if (!mounted || !_fullscreen) return;
    _fullscreen = false;
    Navigator.of(context).maybePop();
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
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

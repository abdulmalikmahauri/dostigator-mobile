/// Что делать с переходом внутри встроенного плеера.
enum NavDecision {
  /// Пускаем: это сам плеер или его служебное окно.
  allow,

  /// Вся страница уходит на чужой сайт — открываем его снаружи.
  openOutside,

  /// Не https и не наш плеер — никуда не пускаем.
  block,
}

/// Куда плееру урока можно ходить: только VK Видео и Rutube.
/// Ссылки на них собирает сервер, но приложение проверяет ещё раз.
abstract final class VideoHosts {
  static const _allowed = ['rutube.ru', 'vk.com', 'vk.ru', 'vkvideo.ru'];

  static bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;

    final host = uri.host.toLowerCase();
    return _allowed.any((h) => host == h || host.endsWith('.$h'));
  }

  /// Служебные окна внутри плеера (сеть доставки, статистика) — его дело:
  /// запрети их, и видео не запустится. Уйти же всей страницей
  /// можно только на сам плеер, остальное — снаружи.
  static NavDecision decide(String url, {required bool isMainFrame}) {
    if (!isMainFrame) return NavDecision.allow;
    if (isAllowed(url)) return NavDecision.allow;

    return Uri.tryParse(url)?.scheme == 'https'
        ? NavDecision.openOutside
        : NavDecision.block;
  }
}

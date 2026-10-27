// Плеер видео урока: на сайте — вставка iframe, в приложении на телефоне —
// встроенный браузер. Выбирается при сборке.
export 'video_embed_io.dart'
    if (dart.library.js_interop) 'video_embed_web.dart';
export 'video_hosts.dart';

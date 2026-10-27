/*
 * Service worker существует ради одного: принимать напоминания о чек-ине,
 * когда вкладка закрыта или браузер свёрнут.
 *
 * Кеширование сборки сюда намеренно не заводится: офлайн приложению нечего
 * показать — все данные приходят с сервера, — а браузер и так держит файлы
 * в кеше и переспрашивает их по ETag.
 */

self.addEventListener('install', function () {
  // Ждать замены вкладок незачем: воркер ничего не перехватывает
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  var payload = {};

  try {
    payload = event.data ? event.data.json() : {};
  } catch (e) {
    // Уведомление без разбираемого содержимого всё равно надо показать:
    // браузер отзовёт подписку, если промолчать
    payload = {};
  }

  var title = payload.title || 'Достигатор';

  event.waitUntil(
    self.registration.showNotification(title, {
      body: payload.body || 'Пора отметить прогресс по цели',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      lang: 'ru',
      // Одна метка на все напоминания о чек-ине: воскресное вытесняет
      // пятничное, а не ложится вторым в шторку
      tag: payload.tag || 'checkin',
      data: { url: payload.url || './' }
    })
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  var target = new URL(
    (event.notification.data && event.notification.data.url) || './',
    self.location.href
  );

  // Уведомление открывает только само приложение. Адрес приходит с нашего
  // сервера, но проверка на месте не даст увести человека на чужой сайт,
  // даже если туда когда-нибудь попадёт посторонняя ссылка
  if (target.origin !== self.location.origin) {
    target = new URL('./', self.location.href);
  }

  target = target.href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (windows) {
      // Приложение уже открыто в соседней вкладке — переводим туда,
      // а не открываем второе окно поверх первого
      for (var i = 0; i < windows.length; i++) {
        if (windows[i].url.indexOf(target) === 0 && 'focus' in windows[i]) {
          return windows[i].focus();
        }
      }

      return self.clients.openWindow(target);
    })
  );
});

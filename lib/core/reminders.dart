import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/resident.dart';
import 'fee_schedule.dart';

/// Напоминания, которые телефон показывает сам: о чек-ине и о взносе.
///
/// Планируются на устройстве, а не приходят с сервера: не нужен ни
/// Firebase, ни серверная инфраструктура пушей, напоминание работает без
/// сети и никуда не отправляет данные о резиденте.
///
/// В браузере этот способ не работает вовсе — там уведомления присылает
/// сервер (см. `core/push`), поэтому на вебе все методы тихо ничего не делают.
class Reminders {
  Reminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Пятница, 10:00 — неделя уже прожита, но ещё есть время
  /// что-то доделать до выходных.
  static const _weekday = DateTime.friday;
  static const _hour = 10;
  static const _minute = 0;

  /// Повторное напоминание в воскресенье вечером — последний шанс
  /// закрыть неделю, пока чек-ин ещё относится к ней.
  static const _followUpWeekday = DateTime.sunday;
  static const _followUpHour = 19;

  static const _weeklyId = 1001;
  static const _followUpId = 1002;

  /// Напоминания о взносе: по одному на день с 25-го по конец месяца,
  /// то есть не больше семи. Номера свои, чтобы не задеть чек-ин.
  static const _feeFirstId = 2001;
  static const _feeSlots = 7;

  static bool _ready = false;

  /// База часовых поясов большая, грузить её дважды незачем. Флаг ставится
  /// сразу, до первой паузы, поэтому одновременные вызовы её не повторят.
  static bool _zonesLoaded = false;

  /// Номер последнего запроса на сверку напоминаний о взносе.
  /// Сверка идёт в несколько шагов; пока она идёт, может прийти новая —
  /// старой тогда нельзя дописывать своё поверх.
  static int _feeSync = 0;

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Готовит службу. Вызывать можно сколько угодно раз: после первой
  /// удачной подготовки повторные вызовы ничего не делают.
  ///
  /// Если канал уведомлений на устройстве недоступен, метод бросает
  /// исключение — экран профиля по нему честно пишет «проверить не удалось».
  /// Вызовы, от которых не должен зависеть показ данных, ловят его сами.
  static Future<void> init() async {
    if (_ready || kIsWeb) return;

    if (!_zonesLoaded) {
      _zonesLoaded = true;
      tzdata.initializeTimeZones();
      // Клуб живёт в одном часовом поясе; брать зону устройства рискованно —
      // у части телефонов она сбита, и напоминание придёт среди ночи.
      tz.setLocalLocation(tz.getLocation('Europe/Moscow'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Без настроек для айфона плагин падает ещё до первого экрана.
        // Разрешение здесь не просим — только по нажатию человека.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    _ready = true;
  }

  /// Спрашивать разрешение сразу на старте — верный способ получить отказ.
  /// Зовём в момент, когда резидент поставил цель: тогда польза очевидна.
  static Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;

    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }

    return await _android?.requestNotificationsPermission() ?? false;
  }

  static Future<bool> isGranted() async {
    await init();
    if (!_ready) return false;

    final ios = _ios;
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }

    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Ставит еженедельные напоминания о чек-ине по целям без отчёта.
  /// Целей может быть несколько, но напоминание одно: три подряд
  /// человек просто смахнёт. Повторный вызов перезаписывает прежние.
  static Future<void> scheduleCheckin({
    required List<String> goalTitles,
  }) async {
    await init();

    if (goalTitles.isEmpty || !await isGranted()) return;

    await cancelCheckin();

    final single = goalTitles.length == 1;
    final body = single
        ? 'Отметьте, где вы по цели «${goalTitles.first}»'
        : 'Без отчёта за неделю целей: ${goalTitles.length}. '
              'Отметьте, где вы по каждой';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'goal_checkin',
        'Чек-ин по цели',
        channelDescription: 'Еженедельное напоминание отметить прогресс',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          '$body. Это займёт полминуты.',
        ),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _scheduleWeekly(
      id: _weeklyId,
      weekday: _weekday,
      hour: _hour,
      title: 'Как прошла неделя?',
      body: body,
      details: details,
    );

    await _scheduleWeekly(
      id: _followUpId,
      weekday: _followUpWeekday,
      hour: _followUpHour,
      title: 'Неделя закрывается',
      body: single
          ? 'Чек-ин по цели «${goalTitles.first}» ещё не сделан'
          : 'Чек-ин ещё не сделан по целям: ${goalTitles.length}',
      details: details,
    );
  }

  /// Чек-ин сделан — напоминания на эту неделю больше не нужны.
  /// Расписание повторяющееся, поэтому на следующую неделю оно
  /// будет поставлено заново при очередной загрузке целей.
  static Future<void> cancelCheckin() async {
    await init();
    if (!_ready) return;

    await _plugin.cancel(id: _weeklyId);
    await _plugin.cancel(id: _followUpId);
  }

  /// Приводит напоминания о взносе к тому, что сказал сервер.
  ///
  /// [notice] равен null, когда напоминать не о чем: взнос оплачен
  /// или его нет вовсе. Тогда поставленные раньше снимаются.
  ///
  /// Слабое место: если организатор отметил оплату, а человек после этого
  /// приложение не открывал, уже поставленные напоминания всё равно придут.
  ///
  /// Вызывается при каждом обновлении профиля, поэтому сбой уведомлений
  /// здесь глушится: вход и показ профиля от него зависеть не должны.
  static Future<void> syncFee(FeeReminder? notice) async {
    try {
      await _syncFee(notice);
    } on Exception catch (e) {
      debugPrint('Напоминание о взносе не поставлено: $e');
    }
  }

  static Future<void> _syncFee(FeeReminder? notice) async {
    final mine = ++_feeSync;

    await init();
    if (!_ready) return;

    for (var slot = 0; slot < _feeSlots; slot++) {
      await _plugin.cancel(id: _feeFirstId + slot);
    }

    if (notice == null || !await isGranted()) return;

    // Пока мы снимали старое, пришла сверка посвежее (например, взнос
    // уже оплачен) — ставить напоминания по устаревшим данным нельзя
    if (mine != _feeSync) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'membership_fee',
        'Взнос',
        channelDescription: 'Напоминание о ежемесячном взносе',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final moments = upcomingFeeMoments(notice.days, DateTime.now());

    for (final (slot, moment) in moments.take(_feeSlots).indexed) {
      if (mine != _feeSync) return;

      await _guarded(
        () => _plugin.zonedSchedule(
          id: _feeFirstId + slot,
          title: notice.title,
          body: notice.body,
          scheduledDate: tz.TZDateTime.from(moment, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        ),
      );
    }
  }

  /// Выход из аккаунта: чужие напоминания на этом телефоне не нужны.
  /// Выйти человек должен в любом случае, поэтому сбой здесь глушится.
  static Future<void> cancelEverything() async {
    try {
      await cancelCheckin();
    } on Exception catch (e) {
      debugPrint('Напоминания о чек-ине не сняты: $e');
    }

    await syncFee(null);
  }

  static Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required String title,
    required String body,
    required NotificationDetails details,
  }) {
    return _guarded(
      () => _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstance(weekday, hour),
        notificationDetails: details,
        // Неточное расписание выбрано намеренно: точные будильники
        // с Android 12 требуют отдельного разрешения, которое система
        // показывает как «может будить телефон». Ради напоминания
        // о чек-ине просить такое — верный способ получить отказ.
        // Сдвиг в пределах часа здесь роли не играет.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      ),
    );
  }

  /// Уведомление — не то, ради чего стоит ронять экран. На части прошивок
  /// планирование запрещено политикой энергосбережения, и тогда мы просто
  /// остаёмся без напоминания.
  static Future<void> _guarded(Future<void> Function() schedule) async {
    try {
      await schedule();
    } on Exception catch (e) {
      debugPrint('Не удалось запланировать напоминание: $e');
    }
  }

  static tz.TZDateTime _nextInstance(int weekday, int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      _minute,
    );

    // Ближайший нужный день недели строго в будущем
    while (when.weekday != weekday || !when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    return when;
  }

  /// Что запланировано сейчас — для экрана профиля и разбора жалоб
  /// вида «мне ничего не приходит».
  static Future<List<PendingNotificationRequest>> pending() async {
    await init();
    if (!_ready) return const [];

    return _plugin.pendingNotificationRequests();
  }
}

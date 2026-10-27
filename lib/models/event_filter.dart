import 'package:flutter/foundation.dart';

import 'event.dart';

/// Что резидент выбрал в фильтре афиши: поиск по названию, формат,
/// тема и «только мои». Неизменяемый — каждое нажатие даёт новый фильтр.
@immutable
class EventFilter {
  const EventFilter({
    this.query = '',
    this.format,
    this.topic,
    this.mineOnly = false,
  });

  static const none = EventFilter();

  final String query;
  final String? format;
  final String? topic;
  final bool mineOnly;

  bool get isEmpty =>
      query.trim().isEmpty && format == null && topic == null && !mineOnly;

  bool matches(ClubEvent e) {
    final q = query.trim().toLowerCase();

    if (q.isNotEmpty && !e.title.toLowerCase().contains(q)) return false;
    if (format != null && e.format != format) return false;
    if (topic != null && e.topic != topic) return false;
    if (mineOnly && !e.isRegistered) return false;

    return true;
  }

  List<ClubEvent> apply(List<ClubEvent> events) =>
      isEmpty ? events : events.where(matches).toList();

  EventFilter withQuery(String value) => EventFilter(
    query: value,
    format: format,
    topic: topic,
    mineOnly: mineOnly,
  );

  /// Повторное нажатие на выбранный формат снимает его.
  EventFilter toggleFormat(String value) => EventFilter(
    query: query,
    format: format == value ? null : value,
    topic: topic,
    mineOnly: mineOnly,
  );

  EventFilter toggleTopic(String value) => EventFilter(
    query: query,
    format: format,
    topic: topic == value ? null : value,
    mineOnly: mineOnly,
  );

  EventFilter toggleMine() => EventFilter(
    query: query,
    format: format,
    topic: topic,
    mineOnly: !mineOnly,
  );

  /// Форматы, которые в списке действительно есть: предлагать «Онлайн»,
  /// когда онлайн-встреч нет, — значит вести в пустой экран.
  static Map<String, String> formatsIn(List<ClubEvent> events) {
    final result = <String, String>{};

    for (final e in events) {
      final value = e.format;
      if (value == null) continue;
      result.putIfAbsent(value, () => e.formatLabel ?? value);
    }

    return result;
  }

  static List<String> topicsIn(List<ClubEvent> events) {
    final topics = {
      for (final e in events)
        if (e.topic != null && e.topic!.trim().isNotEmpty) e.topic!,
    }.toList()..sort();

    return topics;
  }
}

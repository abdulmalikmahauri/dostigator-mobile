import 'task.dart';

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

DateTime _date(dynamic v) =>
    DateTime.tryParse('${v as String? ?? ''}T00:00:00Z') ?? DateTime.utc(1970);

/// Что за дело в плане.
enum PlanKind {
  task,
  habit,
  step,
  event,
  meeting,
  session,
  commitment,
  other;

  static PlanKind parse(String? value) => PlanKind.values.firstWhere(
    (k) => k.name == value,
    orElse: () => PlanKind.other,
  );
}

/// Одно дело дня: задача, привычка, шаг цели, мероприятие…
class PlanItem {
  const PlanItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    this.subtitle,
    this.time,
    this.done,
    this.value,
    this.target,
    this.unit,
  });

  final PlanKind kind;
  final int id;
  final String title;
  final String? subtitle;
  final DateTime date;

  /// «19:00» — у мероприятий, заседаний и встреч группы.
  final String? time;

  /// null — у дела нет отметки «сделано» (мероприятие, заседание).
  final bool? done;
  final int? value;
  final int? target;
  final String? unit;

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    kind: PlanKind.parse(json['kind'] as String?),
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String?,
    date: _date(json['date']),
    time: json['time'] as String?,
    done: json['done'] as bool?,
    value: (json['value'] as num?)?.toInt(),
    target: (json['target'] as num?)?.toInt(),
    unit: json['unit'] as String?,
  );
}

class PlanDay {
  const PlanDay({required this.date, required this.items});

  final DateTime date;
  final List<PlanItem> items;

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
    date: _date(json['date']),
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((i) => PlanItem.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
}

/// День статистики: привычки в плане и сделанные, закрытые задачи.
class StatsDay {
  const StatsDay({
    required this.date,
    required this.habitsPlanned,
    required this.habitsDone,
    required this.tasksDone,
  });

  final DateTime date;
  final int habitsPlanned;
  final int habitsDone;
  final int tasksDone;

  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
    date: _date(json['date']),
    habitsPlanned: _toInt(json['habits_planned']),
    habitsDone: _toInt(json['habits_done']),
    tasksDone: _toInt(json['tasks_done']),
  );
}

class StatsTotals {
  const StatsTotals({
    required this.habitsPercent,
    required this.tasksDone,
    required this.streak,
  });

  final int? habitsPercent;
  final int tasksDone;

  /// Сколько дней подряд все привычки сделаны.
  final int streak;

  factory StatsTotals.fromJson(Map<String, dynamic>? json) => StatsTotals(
    habitsPercent: (json?['habits_percent'] as num?)?.toInt(),
    tasksDone: _toInt(json?['tasks_done']),
    streak: _toInt(json?['streak']),
  );
}

class PlannerStats {
  const PlannerStats({required this.days, required this.totals});

  final List<StatsDay> days;
  final StatsTotals totals;

  factory PlannerStats.fromJson(Map<String, dynamic> json) => PlannerStats(
    days: (json['days'] as List<dynamic>? ?? const [])
        .map((d) => StatsDay.fromJson(d as Map<String, dynamic>))
        .toList(),
    totals: StatsTotals.fromJson(json['totals'] as Map<String, dynamic>?),
  );
}

/// Ответ плана целиком: дни и просроченные задачи.
class PlanResponse {
  const PlanResponse({required this.days, required this.overdue});

  final List<PlanDay> days;
  final List<Task> overdue;

  factory PlanResponse.fromJson(Map<String, dynamic> json) => PlanResponse(
    days: (json['days'] as List<dynamic>? ?? const [])
        .map((d) => PlanDay.fromJson(d as Map<String, dynamic>))
        .toList(),
    overdue: (json['overdue'] as List<dynamic>? ?? const [])
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

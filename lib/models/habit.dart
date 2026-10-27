int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

DateTime _date(dynamic v) =>
    DateTime.tryParse('${v as String? ?? ''}T00:00:00Z') ?? DateTime.utc(1970);

List<int> _days(dynamic v) =>
    (v as List<dynamic>? ?? const []).map((d) => _toInt(d)).toList();

/// Дни недели привычки словами: «каждый день», «по будням», «пн, ср, пт».
abstract final class HabitDays {
  static const short = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

  static String label(List<int> days) {
    final sorted = [...days]..sort();
    final key = sorted.join(',');

    return switch (key) {
      '1,2,3,4,5,6,7' => 'каждый день',
      '1,2,3,4,5' => 'по будням',
      '6,7' => 'по выходным',
      _ => sorted.map((d) => short[d - 1]).join(', '),
    };
  }
}

/// Один день привычки: был ли в плане и что отмечено.
class HabitDay {
  const HabitDay({
    required this.date,
    required this.planned,
    required this.value,
    required this.done,
  });

  /// Московская дата — UTC-полночь.
  final DateTime date;
  final bool planned;
  final int value;
  final bool done;

  factory HabitDay.fromJson(Map<String, dynamic> json) => HabitDay(
    date: _date(json['date']),
    planned: json['planned'] as bool? ?? false,
    value: _toInt(json['value']),
    done: json['done'] as bool? ?? false,
  );

  HabitDay copyWith({int? value, bool? done}) => HabitDay(
    date: date,
    planned: planned,
    value: value ?? this.value,
    done: done ?? this.done,
  );
}

/// Сколько раз сделано из того, что было в плане за 30 дней.
class HabitStability {
  const HabitStability({
    required this.percent,
    required this.planned,
    required this.done,
    required this.inRating,
  });

  static const empty = HabitStability(
    percent: null,
    planned: 0,
    done: 0,
    inRating: false,
  );

  final int? percent;
  final int planned;
  final int done;

  /// В плане уже неделя — процент что-то значит.
  final bool inRating;

  factory HabitStability.fromJson(Map<String, dynamic>? json) => json == null
      ? empty
      : HabitStability(
          percent: (json['percent'] as num?)?.toInt(),
          planned: _toInt(json['planned']),
          done: _toInt(json['done']),
          inRating: json['in_rating'] as bool? ?? false,
        );
}

/// Строка рейтинга: в одной привычке или общий по клубу.
class HabitRatingRow {
  const HabitRatingRow({
    required this.userId,
    required this.name,
    required this.inRating,
    required this.isMe,
    this.avatarUrl,
    this.percent,
    this.target,
    this.habits,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final int? percent;
  final int? target;

  /// Сколько общих привычек учтено — в общем рейтинге.
  final int? habits;
  final bool inRating;
  final bool isMe;

  factory HabitRatingRow.fromJson(Map<String, dynamic> json) => HabitRatingRow(
    userId: _toInt(json['user_id']),
    name: json['name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    percent: (json['percent'] as num?)?.toInt(),
    target: (json['target'] as num?)?.toInt(),
    habits: (json['habits'] as num?)?.toInt(),
    // В общем рейтинге все строки — уже в рейтинге
    inRating: json['in_rating'] as bool? ?? true,
    isMe: json['is_me'] as bool? ?? false,
  );
}

/// Привычка, которую я веду: своя норма, сегодня, неделя, стабильность.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.target,
    required this.days,
    required this.isPublic,
    required this.isListed,
    required this.isOwner,
    required this.participantsCount,
    required this.today,
    required this.week,
    required this.stability,
    this.unit,
    this.calendar = const [],
    this.rating = const [],
  });

  final int id;
  final String title;
  final String? unit;
  final int target;
  final List<int> days;
  final bool isPublic;

  /// Общая и не скрыта организатором — её видят в клубе.
  final bool isListed;
  final bool isOwner;
  final int participantsCount;
  final HabitDay today;
  final List<HabitDay> week;
  final HabitStability stability;

  /// Последние 30 дней — только на экране привычки.
  final List<HabitDay> calendar;
  final List<HabitRatingRow> rating;

  /// Просто «сделал / не сделал» — без количества.
  bool get isCheck => unit == null && target == 1;

  /// Норма словами: «20 страниц», «3 км», «Отметка».
  String get norm => unitText(target, unit);

  String get daysLabel => HabitDays.label(days);

  static String unitText(int value, String? unit) {
    if (unit == null) return value == 1 ? 'Отметка' : '$value раз';
    return '$value $unit';
  }

  /// Сразу после нажатия — до ответа сервера.
  Habit withToday({required int value, required bool done}) => Habit(
    id: id,
    title: title,
    unit: unit,
    target: target,
    days: days,
    isPublic: isPublic,
    isListed: isListed,
    isOwner: isOwner,
    participantsCount: participantsCount,
    today: today.copyWith(value: value, done: done),
    week: [
      for (final d in week)
        d.date == today.date ? d.copyWith(value: value, done: done) : d,
    ],
    stability: stability,
    calendar: calendar,
    rating: rating,
  );

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    unit: json['unit'] as String?,
    target: _toInt(json['target']) == 0 ? 1 : _toInt(json['target']),
    days: _days(json['days']),
    isPublic: json['is_public'] as bool? ?? false,
    isListed: json['is_listed'] as bool? ?? false,
    isOwner: json['is_owner'] as bool? ?? false,
    participantsCount: _toInt(json['participants_count']),
    today: json['today'] is Map<String, dynamic>
        ? HabitDay.fromJson(json['today'] as Map<String, dynamic>)
        : HabitDay(
            date: DateTime.utc(1970),
            planned: false,
            value: 0,
            done: false,
          ),
    week: _list(json['week']).map(HabitDay.fromJson).toList(),
    stability: HabitStability.fromJson(
      json['stability'] as Map<String, dynamic>?,
    ),
    calendar: _list(json['calendar']).map(HabitDay.fromJson).toList(),
    rating: _list(json['rating']).map(HabitRatingRow.fromJson).toList(),
  );
}

/// Общая привычка клуба в каталоге — к ней можно присоединиться.
class ListedHabit {
  const ListedHabit({
    required this.id,
    required this.title,
    required this.target,
    required this.days,
    required this.participantsCount,
    required this.isJoined,
    required this.isOwner,
    this.unit,
    this.ownerName,
  });

  final int id;
  final String title;
  final String? unit;
  final int target;
  final List<int> days;
  final String? ownerName;
  final int participantsCount;
  final bool isJoined;
  final bool isOwner;

  String get norm => Habit.unitText(target, unit);

  String get daysLabel => HabitDays.label(days);

  factory ListedHabit.fromJson(Map<String, dynamic> json) => ListedHabit(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    unit: json['unit'] as String?,
    target: _toInt(json['target']) == 0 ? 1 : _toInt(json['target']),
    days: _days(json['days']),
    ownerName: json['owner_name'] as String?,
    participantsCount: _toInt(json['participants_count']),
    isJoined: json['is_joined'] as bool? ?? false,
    isOwner: json['is_owner'] as bool? ?? false,
  );
}

/// Новая привычка или правка своей.
class HabitDraft {
  const HabitDraft({
    required this.title,
    required this.target,
    required this.days,
    this.unit,
    this.isPublic = false,
  });

  final String title;
  final String? unit;
  final int target;
  final List<int> days;
  final bool isPublic;

  Map<String, dynamic> toJson() {
    final unit = this.unit?.trim();

    return {
      'title': title.trim(),
      'unit': unit == null || unit.isEmpty ? null : unit,
      'target': target,
      'days': [...days]..sort(),
      'is_public': isPublic,
    };
  }
}

List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

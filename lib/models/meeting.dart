int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Заседание клуба, экосистемы или группы — глазами одного резидента:
/// когда, где и как его отметили.
class Meeting {
  const Meeting({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.audienceLabel,
    required this.isPast,
    required this.myStatus,
    required this.myStatusLabel,
    this.place,
  });

  final int id;
  final String title;

  /// Московское время, как его ввёл организатор.
  final DateTime scheduledAt;
  final String? place;

  /// «Весь бизнес-клуб», «Вся экосистема» или название группы.
  final String audienceLabel;
  final bool isPast;

  /// expected | present | absent | excused.
  final String myStatus;
  final String myStatusLabel;

  bool get isMarked => myStatus != 'expected';

  bool get wasPresent => myStatus == 'present';

  /// Подпись отметки для прошедшего заседания. «Ожидается» у прошедшего
  /// звучит странно — пока организатор не отметил, так и пишем.
  String get markLabel => isMarked ? myStatusLabel : 'Не отмечено';

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? 'Заседание',
    scheduledAt: DateTime.parse(json['scheduled_at'] as String),
    place: json['place'] as String?,
    audienceLabel: json['audience_label'] as String? ?? '',
    isPast: json['is_past'] as bool? ?? false,
    myStatus: json['my_status'] as String? ?? 'expected',
    myStatusLabel: json['my_status_label'] as String? ?? 'Ожидается',
  );
}

/// Посещаемость за всё время: на скольких отмеченных заседаниях был.
class MeetingAttendance {
  const MeetingAttendance({required this.held, required this.present});

  static const empty = MeetingAttendance(held: 0, present: 0);

  final int held;
  final int present;

  factory MeetingAttendance.fromJson(Map<String, dynamic>? json) =>
      MeetingAttendance(
        held: _toInt(json?['held']),
        present: _toInt(json?['present']),
      );
}

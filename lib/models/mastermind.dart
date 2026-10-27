int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Как участник выглядит в повестке. Порядок объявления — порядок разбора
/// на встрече: сначала те, кому нужна помощь.
enum AgendaStatus {
  stuck('stuck', 'Просит помощи'),
  silent('silent', 'Молчит'),
  behind('behind', 'Отстаёт'),
  noGoal('no_goal', 'Без цели'),
  onTrack('on_track', 'В графике'),
  achieved('achieved', 'Цель взята');

  const AgendaStatus(this.value, this.label);

  final String value;
  final String label;

  static AgendaStatus parse(String? v) => AgendaStatus.values.firstWhere(
    (s) => s.value == v,
    orElse: () => AgendaStatus.onTrack,
  );

  bool get needsDiscussion => switch (this) {
    AgendaStatus.stuck ||
    AgendaStatus.silent ||
    AgendaStatus.behind ||
    AgendaStatus.noGoal => true,
    AgendaStatus.onTrack || AgendaStatus.achieved => false,
  };
}

class AgendaItem {
  const AgendaItem({
    required this.userId,
    required this.name,
    required this.status,
    required this.needsHelp,
    this.goalTitle,
    this.progressPercent,
    this.expectedPercent,
    this.weeksSilent,
    this.lastComment,
    this.talkingPoint,
    this.metricHidden = false,
  });

  final int userId;
  final String name;
  final AgendaStatus status;
  final bool needsHelp;
  final String? goalTitle;
  final int? progressPercent;
  final int? expectedPercent;
  final int? weeksSilent;
  final String? lastComment;
  final String? talkingPoint;
  final bool metricHidden;

  factory AgendaItem.fromJson(Map<String, dynamic> json) => AgendaItem(
    userId: _toInt(json['user_id']),
    name: json['name'] as String? ?? '',
    status: AgendaStatus.parse(json['status'] as String?),
    needsHelp: json['needs_help'] as bool? ?? false,
    goalTitle: json['goal_title'] as String?,
    progressPercent: (json['progress_percent'] as num?)?.toInt(),
    expectedPercent: (json['expected_percent'] as num?)?.toInt(),
    weeksSilent: (json['weeks_silent'] as num?)?.toInt(),
    lastComment: json['last_comment'] as String?,
    talkingPoint: json['talking_point'] as String?,
    metricHidden: json['metric_hidden'] as bool? ?? false,
  );
}

class Commitment {
  const Commitment({
    required this.id,
    required this.text,
    required this.isDone,
    required this.isOverdue,
    required this.isMine,
    this.name,
    this.dueOn,
  });

  final int id;
  final String text;
  final bool isDone;
  final bool isOverdue;
  final bool isMine;
  final String? name;
  final DateTime? dueOn;

  factory Commitment.fromJson(Map<String, dynamic> json) => Commitment(
    id: _toInt(json['id']),
    text: json['text'] as String? ?? '',
    isDone: json['is_done'] as bool? ?? false,
    isOverdue: json['is_overdue'] as bool? ?? false,
    isMine: json['is_mine'] as bool? ?? true,
    name: json['name'] as String?,
    dueOn: json['due_on'] != null
        ? DateTime.tryParse(json['due_on'] as String)
        : null,
  );
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.isMe,
    this.business,
    this.publicStatus,
    this.publicStatusLabel,
  });

  final int id;
  final String name;
  final bool isMe;
  final String? business;

  /// Обезличенная категория, которую сервер разрешил показать всей группе:
  /// needs_help / no_checkin / working / on_focus / achieved. null — без чипа.
  /// Приватные показатели (цифры, причины) сюда не попадают by design.
  final String? publicStatus;
  final String? publicStatusLabel;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: _toInt(json['id']),
    name: json['name'] as String? ?? '',
    isMe: json['is_me'] as bool? ?? false,
    business: json['business'] as String?,
    publicStatus: json['public_status'] as String?,
    publicStatusLabel: json['public_status_label'] as String?,
  );
}

class SessionBrief {
  const SessionBrief({
    required this.id,
    required this.scheduledAt,
    required this.hasAgenda,
    this.place,
    this.status,
  });

  final int id;
  final DateTime scheduledAt;
  final bool hasAgenda;
  final String? place;
  final String? status;

  factory SessionBrief.fromJson(Map<String, dynamic> json) => SessionBrief(
    id: _toInt(json['id']),
    scheduledAt: DateTime.parse(json['scheduled_at'] as String),
    hasAgenda: json['has_agenda'] as bool? ?? false,
    place: json['place'] as String?,
    status: json['status'] as String?,
  );

  /// null вместо исключения: неполный ответ сервера (без даты) не должен
  /// ронять разбор всей группы — встреча без даты для UI бесполезна.
  static SessionBrief? tryFrom(dynamic json) {
    if (json is! Map<String, dynamic>) return null;

    final raw = json['scheduled_at'];
    if (raw is! String || DateTime.tryParse(raw) == null) return null;

    return SessionBrief.fromJson(json);
  }
}

class MastermindGroup {
  const MastermindGroup({
    required this.id,
    required this.name,
    required this.isCurator,
    required this.members,
    required this.membersCount,
    this.place,
    this.curatorName,
    this.nextSession,
    this.lastSession,
    this.lastSessionNotes,
  });

  final int id;
  final String name;
  final bool isCurator;
  final List<GroupMember> members;
  final String? place;
  final String? curatorName;
  final SessionBrief? nextSession;

  /// Последняя проведённая встреча — точка входа в протокол.
  final SessionBrief? lastSession;
  final String? lastSessionNotes;

  /// Сервер считает по активным участникам; локальный список может быть
  /// урезан, поэтому доверяем счётчику, а не length.
  final int membersCount;

  factory MastermindGroup.fromJson(
    Map<String, dynamic> json,
  ) => MastermindGroup(
    id: _toInt(json['id']),
    name: json['name'] as String? ?? '',
    isCurator: json['is_curator'] as bool? ?? false,
    place: json['place'] as String?,
    curatorName: (json['curator'] as Map<String, dynamic>?)?['name'] as String?,
    members: (json['members'] as List<dynamic>? ?? [])
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList(),
    membersCount:
        (json['members_count'] as num?)?.toInt() ??
        (json['members'] as List<dynamic>? ?? []).length,
    nextSession: SessionBrief.tryFrom(json['next_session']),
    lastSession: SessionBrief.tryFrom(json['last_session']),
    lastSessionNotes:
        (json['last_session'] as Map<String, dynamic>?)?['notes'] as String?,
  );
}

/// Посещаемость встречи. Сервер отдаёт список в детали сессии;
/// показывать его или нет — решает роль зрителя (isCurator).
class SessionAttendance {
  const SessionAttendance({
    required this.userId,
    required this.name,
    required this.status,
    required this.label,
  });

  final int userId;
  final String name;
  final String status;
  final String label;

  bool get wasPresent => status == 'present';

  factory SessionAttendance.fromJson(Map<String, dynamic> json) =>
      SessionAttendance(
        userId: _toInt(json['user_id']),
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        label: json['status_label'] as String? ?? '',
      );
}

class MastermindSession {
  const MastermindSession({
    required this.id,
    required this.scheduledAt,
    required this.status,
    required this.isCurator,
    required this.agenda,
    required this.summary,
    required this.commitments,
    this.attendance = const [],
    this.place,
    this.notes,
    this.groupName,
    this.heldAt,
  });

  final int id;
  final DateTime scheduledAt;
  final String status;
  final bool isCurator;
  final List<AgendaItem> agenda;
  final Map<String, int> summary;
  final List<Commitment> commitments;
  final List<SessionAttendance> attendance;
  final String? place;
  final String? notes;
  final String? groupName;
  final DateTime? heldAt;

  bool get isHeld => status == 'held';

  /// Обязательства текущего пользователя — единственное, что обычный
  /// участник видит в протоколе из этого списка.
  List<Commitment> get myCommitments =>
      commitments.where((c) => c.isMine).toList();

  int get needAttention =>
      (summary['stuck'] ?? 0) +
      (summary['silent'] ?? 0) +
      (summary['behind'] ?? 0) +
      (summary['no_goal'] ?? 0);

  factory MastermindSession.fromJson(Map<String, dynamic> json) {
    final rawSummary =
        json['agenda_summary'] as Map<String, dynamic>? ?? const {};

    return MastermindSession(
      id: _toInt(json['id']),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String? ?? 'planned',
      isCurator: json['is_curator'] as bool? ?? false,
      place: json['place'] as String?,
      notes: json['notes'] as String?,
      groupName: json['group_name'] as String?,
      agenda: (json['agenda'] as List<dynamic>? ?? [])
          .map((e) => AgendaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: rawSummary.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      commitments: (json['commitments'] as List<dynamic>? ?? [])
          .map((e) => Commitment.fromJson(e as Map<String, dynamic>))
          .toList(),
      attendance: (json['attendance'] as List<dynamic>? ?? [])
          .map((e) => SessionAttendance.fromJson(e as Map<String, dynamic>))
          .toList(),
      heldAt: json['held_at'] != null
          ? DateTime.tryParse(json['held_at'] as String)
          : null,
    );
  }
}

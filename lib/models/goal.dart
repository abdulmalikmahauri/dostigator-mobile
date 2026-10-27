double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

class GoalStep {
  const GoalStep({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueOn,
  });

  final int id;
  final String title;
  final bool isDone;
  final DateTime? dueOn;

  factory GoalStep.fromJson(Map<String, dynamic> json) => GoalStep(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    isDone: json['is_done'] as bool? ?? false,
    dueOn: json['due_on'] != null
        ? DateTime.tryParse(json['due_on'] as String)
        : null,
  );
}

class GoalCheckin {
  const GoalCheckin({
    required this.weekStart,
    required this.metricValue,
    required this.needsHelp,
    this.comment,
  });

  final DateTime weekStart;
  final double metricValue;
  final bool needsHelp;
  final String? comment;

  factory GoalCheckin.fromJson(Map<String, dynamic> json) => GoalCheckin(
    weekStart: DateTime.parse(json['week_start'] as String),
    metricValue: _toDouble(json['metric_value']),
    needsHelp: json['needs_help'] as bool? ?? false,
    comment: json['comment'] as String?,
  );
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.metricName,
    required this.metricFrom,
    required this.metricTarget,
    required this.metricCurrent,
    required this.progressPercent,
    required this.isReached,
    required this.deadline,
    required this.daysLeft,
    required this.status,
    required this.statusLabel,
    required this.isMain,
    required this.visibility,
    required this.hideAbsoluteValues,
    required this.checkedInThisWeek,
    required this.missedWeeks,
    required this.steps,
    required this.checkins,
    this.why,
    this.metricUnit,
    this.outcomeNote,
  });

  final int id;
  final String title;
  final String? why;

  final String metricName;
  final String? metricUnit;
  final double metricFrom;
  final double metricTarget;
  final double metricCurrent;

  final int progressPercent;
  final bool isReached;

  final DateTime deadline;
  final int daysLeft;

  final String status;
  final String statusLabel;

  /// Главная из целей в работе: её видит группа и первой показывает Пульс.
  final bool isMain;
  final String visibility;
  final bool hideAbsoluteValues;

  final bool checkedInThisWeek;
  final int missedWeeks;

  final List<GoalStep> steps;
  final List<GoalCheckin> checkins;
  final String? outcomeNote;

  bool get isActive => status == 'active';

  bool get isOverdue => isActive && daysLeft < 0;

  /// Цель может идти и на снижение — от этого зависит подпись на экране.
  bool get isDecreasing => metricTarget < metricFrom;

  int get doneSteps => steps.where((s) => s.isDone).length;

  factory Goal.fromJson(Map<String, dynamic> json) {
    final metric = json['metric'] as Map<String, dynamic>? ?? const {};

    return Goal(
      id: _toInt(json['id']),
      title: json['title'] as String? ?? '',
      why: json['why'] as String?,
      metricName: metric['name'] as String? ?? '',
      metricUnit: metric['unit'] as String?,
      metricFrom: _toDouble(metric['from']),
      metricTarget: _toDouble(metric['target']),
      metricCurrent: _toDouble(metric['current']),
      progressPercent: _toInt(json['progress_percent']),
      isReached: json['is_reached'] as bool? ?? false,
      deadline: DateTime.parse(json['deadline'] as String),
      daysLeft: _toInt(json['days_left']),
      status: json['status'] as String? ?? 'active',
      statusLabel: json['status_label'] as String? ?? '',
      isMain: json['is_main'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'group',
      hideAbsoluteValues: json['hide_absolute_values'] as bool? ?? false,
      checkedInThisWeek: json['checked_in_this_week'] as bool? ?? false,
      missedWeeks: _toInt(json['missed_weeks']),
      outcomeNote: json['outcome_note'] as String?,
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((e) => GoalStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      checkins: (json['checkins'] as List<dynamic>? ?? [])
          .map((e) => GoalCheckin.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

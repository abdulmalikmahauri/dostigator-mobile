import 'package:intl/intl.dart';

/// Кто видит задачу. Личную не видит никто, даже организаторы.
enum TaskVisibility {
  public('public', 'Видят все', 'Появится в вашей карточке в клубе'),
  internal(
    'internal',
    'Видят организаторы',
    'Увидят куратор и организаторы клуба',
  ),
  private('private', 'Только я', 'Не видит никто, кроме вас');

  const TaskVisibility(this.value, this.label, this.hint);

  final String value;
  final String label;
  final String hint;

  static TaskVisibility parse(String? value) =>
      TaskVisibility.values.firstWhere(
        (v) => v.value == value,
        orElse: () => TaskVisibility.private,
      );
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.visibility,
    required this.isDone,
    required this.isOverdue,
    required this.isHidden,
    this.notes,
    this.dueOn,
  });

  final int id;
  final String title;
  final String? notes;

  /// Срок — московская дата, UTC-полночь.
  final DateTime? dueOn;
  final TaskVisibility visibility;
  final bool isDone;
  final bool isOverdue;

  /// Скрыта организатором по жалобе: другим не видна.
  final bool isHidden;

  Task toggled() => Task(
    id: id,
    title: title,
    notes: notes,
    dueOn: dueOn,
    visibility: visibility,
    isDone: !isDone,
    isOverdue: false,
    isHidden: isHidden,
  );

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    notes: json['notes'] as String?,
    dueOn: json['due_on'] == null
        ? null
        : DateTime.tryParse('${json['due_on']}T00:00:00Z'),
    visibility: TaskVisibility.parse(json['visibility'] as String?),
    isDone: json['is_done'] as bool? ?? false,
    isOverdue: json['is_overdue'] as bool? ?? false,
    isHidden: json['is_hidden'] as bool? ?? false,
  );
}

/// Заполненная форма задачи.
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.notes,
    this.dueOn,
    this.visibility = TaskVisibility.private,
  });

  final String title;
  final String? notes;
  final DateTime? dueOn;
  final TaskVisibility visibility;

  static final _day = DateFormat('yyyy-MM-dd');

  Map<String, dynamic> toJson() {
    final notes = this.notes?.trim();

    return {
      'title': title.trim(),
      'notes': notes == null || notes.isEmpty ? null : notes,
      'due_on': dueOn == null ? null : _day.format(dueOn!),
      'visibility': visibility.value,
    };
  }
}

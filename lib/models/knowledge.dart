import '../core/formatting.dart';

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

int? _toIntOrNull(dynamic v) => (v as num?)?.toInt();

/// «45 мин», «1 ч», «1 ч 15 мин».
String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes мин';

  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours ч' : '$hours ч $rest мин';
}

/// Курс, лекция или мастер-класс в базе знаний.
class Course {
  const Course({
    required this.id,
    required this.kind,
    required this.kindLabel,
    required this.title,
    required this.lessonsCount,
    required this.completedCount,
    required this.isAvailable,
    this.description,
    this.coverUrl,
    this.durationMinutes,
    this.minTierLabel,
    this.firstLessonId,
  });

  final int id;
  final String kind;
  final String kindLabel;
  final String title;
  final String? description;
  final String? coverUrl;
  final int lessonsCount;
  final int? durationMinutes;
  final int completedCount;

  /// Закрытое по уровню видно, но смотреть его нельзя.
  final bool isAvailable;
  final String? minTierLabel;

  /// Лекция из одного урока открывается сразу уроком.
  final int? firstLessonId;

  /// «Пройдено 2 из 5», «Пройдено»; пока ничего не начато — пусто.
  String? get progressLabel {
    if (completedCount <= 0 || lessonsCount == 0) return null;
    if (completedCount >= lessonsCount) return 'Пройдено';
    return 'Пройдено $completedCount из $lessonsCount';
  }

  /// «5 уроков · 1 ч 15 мин».
  String get metaLabel {
    final minutes = durationMinutes;
    return [
      Fmt.plural(lessonsCount, 'урок', 'урока', 'уроков'),
      if (minutes != null && minutes > 0) durationLabel(minutes),
    ].join(' · ');
  }

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: _toInt(json['id']),
    kind: json['kind'] as String? ?? 'course',
    kindLabel: json['kind_label'] as String? ?? 'Материал',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    coverUrl: json['cover_url'] as String?,
    lessonsCount: _toInt(json['lessons_count']),
    durationMinutes: _toIntOrNull(json['duration_minutes']),
    completedCount: _toInt(json['completed_count']),
    isAvailable: json['is_available'] as bool? ?? true,
    minTierLabel: json['min_tier_label'] as String?,
    firstLessonId: _toIntOrNull(json['first_lesson_id']),
  );
}

/// Урок в оглавлении курса.
class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.title,
    required this.hasVideo,
    required this.isCompleted,
    this.durationMinutes,
  });

  final int id;
  final String title;
  final int? durationMinutes;
  final bool hasVideo;
  final bool isCompleted;

  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    durationMinutes: _toIntOrNull(json['duration_minutes']),
    hasVideo: json['has_video'] as bool? ?? false,
    isCompleted: json['is_completed'] as bool? ?? false,
  );
}

class CourseDetail {
  const CourseDetail({required this.course, required this.lessons});

  final Course course;
  final List<LessonSummary> lessons;

  factory CourseDetail.fromJson(Map<String, dynamic> json) => CourseDetail(
    course: Course.fromJson(json),
    lessons: (json['lessons'] as List<dynamic>? ?? const [])
        .map((l) => LessonSummary.fromJson(l as Map<String, dynamic>))
        .toList(),
  );
}

/// Видео урока: адрес встроенного плеера и страница на сайте.
class LessonVideo {
  const LessonVideo({
    required this.provider,
    required this.providerLabel,
    required this.embedUrl,
    required this.watchUrl,
  });

  final String provider;
  final String providerLabel;
  final String embedUrl;
  final String watchUrl;

  factory LessonVideo.fromJson(Map<String, dynamic> json) => LessonVideo(
    provider: json['provider'] as String? ?? '',
    providerLabel: json['provider_label'] as String? ?? 'сайте',
    embedUrl: json['embed_url'] as String? ?? '',
    watchUrl: json['watch_url'] as String? ?? '',
  );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.courseKindLabel,
    required this.title,
    required this.number,
    required this.total,
    required this.isAvailable,
    required this.isCompleted,
    this.durationMinutes,
    this.minTierLabel,
    this.body,
    this.video,
    this.prevId,
    this.nextId,
  });

  final int id;
  final int courseId;
  final String courseTitle;
  final String courseKindLabel;
  final String title;
  final int? durationMinutes;
  final int number;
  final int total;
  final bool isAvailable;
  final String? minTierLabel;

  /// Закрытому по уровню текст и видео не приходят.
  final String? body;
  final LessonVideo? video;
  final bool isCompleted;
  final int? prevId;
  final int? nextId;

  /// Текст абзацами: пустая строка — новый абзац.
  List<String> get paragraphs => (body ?? '')
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: _toInt(json['id']),
    courseId: _toInt(json['course_id']),
    courseTitle: json['course_title'] as String? ?? '',
    courseKindLabel: json['course_kind_label'] as String? ?? '',
    title: json['title'] as String? ?? '',
    durationMinutes: _toIntOrNull(json['duration_minutes']),
    number: _toInt(json['number']),
    total: _toInt(json['total']),
    isAvailable: json['is_available'] as bool? ?? true,
    minTierLabel: json['min_tier_label'] as String?,
    body: json['body'] as String?,
    video: json['video'] is Map<String, dynamic>
        ? LessonVideo.fromJson(json['video'] as Map<String, dynamic>)
        : null,
    isCompleted: json['is_completed'] as bool? ?? false,
    prevId: _toIntOrNull(json['prev_id']),
    nextId: _toIntOrNull(json['next_id']),
  );
}

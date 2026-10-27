import 'package:intl/intl.dart';

/// Мероприятие, которое резидент предложил сам, и что по нему решили.
class EventProposal {
  const EventProposal({
    required this.id,
    required this.title,
    required this.typeLabel,
    required this.formatLabel,
    required this.startsAt,
    required this.status,
    required this.statusLabel,
    this.place,
    this.rejectionReason,
  });

  final int id;
  final String title;
  final String typeLabel;
  final String formatLabel;
  final DateTime startsAt;
  final String? place;

  /// pending | published | rejected | cancelled | draft.
  final String status;
  final String statusLabel;
  final String? rejectionReason;

  /// Отозвать можно, пока организаторы не рассмотрели.
  bool get canWithdraw => status == 'pending';

  factory EventProposal.fromJson(Map<String, dynamic> json) => EventProposal(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    typeLabel: json['type_label'] as String? ?? 'Мероприятие',
    formatLabel: json['format_label'] as String? ?? '',
    startsAt:
        DateTime.tryParse(json['starts_at'] as String? ?? '') ??
        (throw const FormatException('Нет даты предложения')),
    place: json['place'] as String?,
    status: json['status'] as String? ?? 'pending',
    statusLabel: json['status_label'] as String? ?? 'На согласовании',
    rejectionReason: json['rejection_reason'] as String?,
  );
}

/// Заполненная форма предложения — то, что уходит организаторам.
class EventProposalDraft {
  const EventProposalDraft({
    required this.title,
    required this.type,
    required this.format,
    required this.startsAt,
    this.endsAt,
    this.topic,
    this.description,
    this.place,
    this.address,
    this.capacity,
  });

  final String title;
  final String type;
  final String format;

  /// Московское время, как его выбрал резидент.
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? topic;
  final String? description;
  final String? place;
  final String? address;
  final int? capacity;

  static final _wallClock = DateFormat('yyyy-MM-dd HH:mm');

  /// Время уходит без часового пояса: сервер хранит клубное время как есть.
  /// Пустые поля не отправляем вовсе.
  Map<String, dynamic> toJson() {
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

    final optional = <String, Object?>{
      'topic': clean(topic),
      'description': clean(description),
      'place': clean(place),
      'address': clean(address),
      'capacity': capacity,
      'ends_at': endsAt == null ? null : _wallClock.format(endsAt!),
    };

    return {
      'title': title.trim(),
      'type': type,
      'format': format,
      'starts_at': _wallClock.format(startsAt),
      for (final entry in optional.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }
}

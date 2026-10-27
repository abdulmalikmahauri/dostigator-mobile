import '../core/formatting.dart';

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.title,
    required this.typeLabel,
    required this.startsAt,
    required this.isFree,
    required this.isPast,
    required this.isFull,
    required this.isAvailable,
    required this.isRegistered,
    required this.checkedIn,
    required this.price,
    this.type,
    this.description,
    this.endsAt,
    this.place,
    this.address,
    this.speaker,
    this.capacity,
    this.seatsLeft,
    this.minTierLabel,
    this.unavailableReason,
    this.ticket,
    this.format,
    this.formatLabel,
    this.topic,
    this.seatsTaken,
    this.partners = const [],
    this.photosCount = 0,
    this.photosLink,
  });

  final int id;
  final String title;
  final String typeLabel;
  final DateTime startsAt;
  final bool isFree;
  final bool isPast;
  final bool isFull;
  final bool isAvailable;
  final bool isRegistered;
  final bool checkedIn;
  final int price;
  final String? type;
  final String? description;
  final DateTime? endsAt;
  final String? place;
  final String? address;
  final String? speaker;
  final int? capacity;
  final int? seatsLeft;
  final String? minTierLabel;
  final String? unavailableReason;
  final String? ticket;

  /// offline | online | hybrid. Старый сервер формата не присылает.
  final String? format;
  final String? formatLabel;

  /// Тема, которую задал организатор: «Маркетинг», «Финансы».
  final String? topic;
  final int? seatsTaken;
  final List<EventPartner> partners;

  /// Сколько фото с мероприятия уже лежит у нас на сервере.
  final int photosCount;

  /// Папка на Яндекс Диске целиком — для тех, кому мало превью.
  final String? photosLink;

  /// Можно ли нажать «Записаться» прямо сейчас.
  bool get canRegister => isAvailable && !isPast && !isFull && !isRegistered;

  /// Стоит ли предупредить, что мест почти нет. Порог намеренно низкий:
  /// «осталось 12 мест» никого не торопит, «осталось 3» — торопит.
  bool get isRunningOut =>
      seatsLeft != null && seatsLeft! > 0 && seatsLeft! <= 3;

  /// «Осталось 5 мест из 30» — одинаково в афише и в карточке.
  String? get seatsSummary {
    if (isFull) return 'Мест нет';

    final left = seatsLeft;
    if (left == null) return null;

    final text = 'Осталось ${Fmt.plural(left, 'место', 'места', 'мест')}';
    return capacity == null ? text : '$text из $capacity';
  }

  factory ClubEvent.fromJson(Map<String, dynamic> json) => ClubEvent(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    typeLabel: json['type_label'] as String? ?? 'Мероприятие',
    type: json['type'] as String?,
    description: json['description'] as String?,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: json['ends_at'] != null
        ? DateTime.tryParse(json['ends_at'] as String)
        : null,
    place: json['place'] as String?,
    address: json['address'] as String?,
    speaker: json['speaker'] as String?,
    price: _toInt(json['price']),
    isFree: json['is_free'] as bool? ?? true,
    isPast: json['is_past'] as bool? ?? false,
    capacity: (json['capacity'] as num?)?.toInt(),
    seatsLeft: (json['seats_left'] as num?)?.toInt(),
    isFull: json['is_full'] as bool? ?? false,
    minTierLabel: json['min_tier_label'] as String?,
    isAvailable: json['is_available'] as bool? ?? true,
    unavailableReason: json['unavailable_reason'] as String?,
    isRegistered: json['is_registered'] as bool? ?? false,
    checkedIn: json['checked_in'] as bool? ?? false,
    ticket: json['ticket'] as String?,
    format: json['format'] as String?,
    formatLabel: json['format_label'] as String?,
    topic: json['topic'] as String?,
    seatsTaken: (json['seats_taken'] as num?)?.toInt(),
    partners: (json['partners'] as List<dynamic>? ?? const [])
        .map((p) => EventPartner.fromJson(p as Map<String, dynamic>))
        .toList(),
    photosCount: _toInt(json['photos_count']),
    photosLink: json['photos_link'] as String?,
  );
}

/// Партнёр, который участвует в мероприятии.
class EventPartner {
  const EventPartner({required this.id, required this.name, this.category});

  final int id;
  final String name;
  final String? category;

  factory EventPartner.fromJson(Map<String, dynamic> json) => EventPartner(
    id: _toInt(json['id']),
    name: json['name'] as String? ?? '',
    category: json['category'] as String?,
  );
}

/// Фото с прошедшего мероприятия: уменьшенная копия для сетки
/// и крупная — для просмотра во весь экран.
class EventPhoto {
  const EventPhoto({
    required this.id,
    required this.thumbUrl,
    required this.url,
  });

  final int id;
  final String thumbUrl;
  final String url;

  factory EventPhoto.fromJson(Map<String, dynamic> json) => EventPhoto(
    id: _toInt(json['id']),
    thumbUrl: json['thumb_url'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );
}

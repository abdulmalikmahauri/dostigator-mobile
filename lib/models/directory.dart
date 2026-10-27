int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Запись каталога резидентов.
///
/// Поля приходят уже отфильтрованными сервером: что скрыто настройками
/// приватности или недоступно по уровню членства — приходит пустым.
/// Приложение ничего не решает само, только показывает.
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.name,
    required this.isMe,
    required this.canContact,
    this.isClub = false,
    this.avatarUrl,
    this.privileges = const [],
    this.tasks = const [],
    this.habits = const [],
    this.city,
    this.tierLabel,
    this.businessName,
    this.niche,
    this.description,
    this.canHelp,
    this.lookingFor,
    this.employeesCount,
    this.website,
    this.instagram,
    this.whatsappUrl,
    this.telegramUrl,
  });

  final int id;
  final String name;
  final bool isMe;
  final bool canContact;

  /// Член бизнес-клуба. В разделе «Экосистема» такие отмечены меткой.
  final bool isClub;
  final String? avatarUrl;

  /// Привилегии, которые этот резидент даёт клубу через свой бизнес.
  final List<ResidentPrivilege> privileges;

  /// Задачи «видят все» и общие привычки — только в карточке одного
  /// резидента; в списке их нет.
  final List<PublicTask> tasks;
  final List<PublicHabit> habits;
  final String? city;
  final String? tierLabel;
  final String? businessName;
  final String? niche;
  final String? description;
  final String? canHelp;
  final String? lookingFor;
  final int? employeesCount;
  final String? website;
  final String? instagram;
  final String? whatsappUrl;
  final String? telegramUrl;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// Ссылка на профиль в Instagram. Организатор записывает кто как:
  /// «@name», «name», полный адрес — приводим к одному виду, иначе
  /// кнопка откроет пустоту.
  String? get instagramUrl {
    final raw = instagram?.trim();
    if (raw == null || raw.isEmpty) return null;

    var handle = raw;
    final match = RegExp(
      r'instagram\.com/([A-Za-z0-9._]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) {
      handle = match.group(1)!;
    }
    handle = handle.replaceFirst(RegExp(r'^@'), '').replaceAll('/', '');

    return handle.isEmpty ? null : 'https://instagram.com/$handle';
  }

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) => DirectoryEntry(
    id: _toInt(json['id']),
    name: json['name'] as String? ?? '',
    isMe: json['is_me'] as bool? ?? false,
    canContact: json['can_contact'] as bool? ?? false,
    isClub: json['is_club'] as bool? ?? false,
    avatarUrl: json['avatar_url'] as String?,
    privileges: (json['privileges'] as List<dynamic>? ?? const [])
        .map((e) => ResidentPrivilege.fromJson(e as Map<String, dynamic>))
        .toList(),
    tasks: (json['tasks'] as List<dynamic>? ?? const [])
        .map((e) => PublicTask.fromJson(e as Map<String, dynamic>))
        .toList(),
    habits: (json['habits'] as List<dynamic>? ?? const [])
        .map((e) => PublicHabit.fromJson(e as Map<String, dynamic>))
        .toList(),
    city: json['city'] as String?,
    tierLabel: json['tier_label'] as String?,
    businessName: json['business_name'] as String?,
    niche: json['niche'] as String?,
    description: json['description'] as String?,
    canHelp: json['can_help'] as String?,
    lookingFor: json['looking_for'] as String?,
    employeesCount: (json['employees_count'] as num?)?.toInt(),
    website: json['website'] as String?,
    instagram: json['instagram'] as String?,
    whatsappUrl: json['whatsapp_url'] as String?,
    telegramUrl: json['telegram_url'] as String?,
  );
}

/// Привилегия в карточке резидента: что даёт его бизнес членам клуба.
class ResidentPrivilege {
  const ResidentPrivilege({
    required this.id,
    required this.partnerId,
    required this.partner,
    required this.title,
    required this.benefit,
    required this.isAvailable,
    this.conditions,
    this.minTierLabel,
  });

  final int id;
  final int partnerId;
  final String partner;
  final String title;
  final String benefit;
  final bool isAvailable;
  final String? conditions;
  final String? minTierLabel;

  factory ResidentPrivilege.fromJson(Map<String, dynamic> json) =>
      ResidentPrivilege(
        id: _toInt(json['id']),
        partnerId: _toInt(json['partner_id']),
        partner: json['partner'] as String? ?? '',
        title: json['title'] as String? ?? '',
        benefit: json['benefit'] as String? ?? 'Привилегия',
        isAvailable: json['is_available'] as bool? ?? true,
        conditions: json['conditions'] as String?,
        minTierLabel: json['min_tier_label'] as String?,
      );
}

/// Резидент, чей бизнес даёт привилегию. Коротко: для подписи в карте.
class PartnerResident {
  const PartnerResident({required this.id, required this.name, this.avatarUrl});

  final int id;
  final String name;
  final String? avatarUrl;

  factory PartnerResident.fromJson(Map<String, dynamic> json) =>
      PartnerResident(
        id: _toInt(json['id']),
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class PartnerOffer {
  const PartnerOffer({
    required this.id,
    required this.title,
    required this.benefit,
    required this.isAvailable,
    this.conditions,
    this.validUntil,
    this.minTierLabel,
  });

  final int id;
  final String title;
  final String benefit;
  final bool isAvailable;
  final String? conditions;
  final DateTime? validUntil;
  final String? minTierLabel;

  factory PartnerOffer.fromJson(Map<String, dynamic> json) => PartnerOffer(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    benefit: json['benefit'] as String? ?? 'Привилегия',
    isAvailable: json['is_available'] as bool? ?? true,
    conditions: json['conditions'] as String?,
    validUntil: json['valid_until'] != null
        ? DateTime.tryParse(json['valid_until'] as String)
        : null,
    minTierLabel: json['min_tier_label'] as String?,
  );
}

class Partner {
  const Partner({
    required this.id,
    required this.name,
    required this.offers,
    this.resident,
    this.category,
    this.description,
    this.address,
    this.website,
  });

  final int id;
  final String name;
  final List<PartnerOffer> offers;

  /// Null — внешний партнёр, не резидент.
  final PartnerResident? resident;
  final String? category;
  final String? description;
  final String? address;
  final String? website;

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
    id: _toInt(json['id']),
    name: json['name'] as String? ?? '',
    resident: json['resident'] is Map<String, dynamic>
        ? PartnerResident.fromJson(json['resident'] as Map<String, dynamic>)
        : null,
    category: json['category'] as String?,
    description: json['description'] as String?,
    address: json['address'] as String?,
    website: json['website'] as String?,
    offers: (json['offers'] as List<dynamic>? ?? [])
        .map((e) => PartnerOffer.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class Savings {
  const Savings({
    required this.total,
    required this.confirmed,
    required this.count,
  });

  final int total;
  final int confirmed;
  final int count;

  factory Savings.fromJson(Map<String, dynamic> json) => Savings(
    total: _toInt(json['total']),
    confirmed: _toInt(json['confirmed']),
    count: _toInt(json['count']),
  );

  static const empty = Savings(total: 0, confirmed: 0, count: 0);
}

/// Сводка сообщества из meta.stats ответа GET /directory.
/// Показывается компактной строкой — поиск на экране «Клуб» важнее статистики.
class ClubStats {
  const ClubStats({
    required this.residents,
    required this.club,
    required this.niches,
    required this.partners,
  });

  /// Все действующие резиденты — это и есть экосистема.
  final int residents;

  /// Из них — члены бизнес-клуба.
  final int club;
  final int niches;
  final int partners;

  /// Бэкенд может не прислать stats — тогда строку сводки просто не рисуем.
  bool get isEmpty => residents == 0 && niches == 0 && partners == 0;

  factory ClubStats.fromJson(Map<String, dynamic> json) => ClubStats(
    residents: _toInt(json['residents']),
    club: _toInt(json['club']),
    niches: _toInt(json['niches']),
    partners: _toInt(json['partners']),
  );

  static const empty = ClubStats(residents: 0, club: 0, niches: 0, partners: 0);
}

/// Задача резидента, которую он открыл всем.
class PublicTask {
  const PublicTask({required this.id, required this.title, this.dueOn});

  final int id;
  final String title;
  final DateTime? dueOn;

  factory PublicTask.fromJson(Map<String, dynamic> json) => PublicTask(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    dueOn: json['due_on'] == null
        ? null
        : DateTime.tryParse('${json['due_on']}T00:00:00Z'),
  );
}

/// Общая привычка резидента и его стабильность в ней.
class PublicHabit {
  const PublicHabit({
    required this.id,
    required this.title,
    required this.target,
    this.unit,
    this.percent,
  });

  final int id;
  final String title;
  final String? unit;
  final int target;

  /// Пока неделя плана не набралась — пусто.
  final int? percent;

  factory PublicHabit.fromJson(Map<String, dynamic> json) => PublicHabit(
    id: _toInt(json['id']),
    title: json['title'] as String? ?? '',
    unit: json['unit'] as String?,
    target: _toInt(json['target']),
    percent: (json['percent'] as num?)?.toInt(),
  );
}

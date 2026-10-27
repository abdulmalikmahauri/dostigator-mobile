/// Разбор JSON намеренно защитный.
///
/// PHP отдаёт целые значения как int, дробные как double. В Dart прямое
/// приведение `json['x'] as double` на числе 900000 падает в рантайме,
/// поэтому все числа читаем через num.
double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

class Membership {
  const Membership({
    required this.tier,
    required this.tierLabel,
    required this.statusLabel,
    required this.isOverdue,
    this.paidUntil,
    this.monthlyFee,
  });

  final String tier;
  final String tierLabel;
  final String statusLabel;
  final bool isOverdue;
  final DateTime? paidUntil;
  final double? monthlyFee;

  bool get isClub => tier == 'club';

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    tier: json['tier'] as String? ?? '',
    tierLabel: json['tier_label'] as String? ?? '',
    statusLabel: json['status_label'] as String? ?? '',
    isOverdue: json['is_overdue'] as bool? ?? false,
    paidUntil: json['paid_until'] != null
        ? DateTime.tryParse(json['paid_until'] as String)
        : null,
    monthlyFee: json['monthly_fee'] == null
        ? null
        : _toDouble(json['monthly_fee']),
  );
}

/// Напоминание о взносе, как его описал сервер: что сказать и в какие дни.
/// Приложение само ставит уведомления на эти дни — см. `Reminders.syncFee`.
class FeeReminder {
  const FeeReminder({
    required this.title,
    required this.body,
    required this.days,
  });

  final String title;
  final String body;

  /// Дни в виде `2026-10-25`, начиная с сегодняшнего.
  final List<String> days;

  factory FeeReminder.fromJson(Map<String, dynamic> json) => FeeReminder(
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    days: (json['days'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
  );
}

/// Переключатели «да/нет» из ответа сервера. Пустой набор PHP отдаёт
/// списком, а не объектом, поэтому форму ответа здесь не предполагаем.
Map<String, bool> _flags(dynamic raw) {
  if (raw is! Map) return const {};

  return {
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is bool)
        entry.key as String: entry.value as bool,
  };
}

class ResidentProfile {
  const ResidentProfile({
    this.businessName,
    this.niche,
    this.description,
    this.canHelp,
    this.lookingFor,
    this.website,
    this.instagram,
    this.employeesCount,
    this.visibility = const {},
  });

  final String? businessName;
  final String? niche;
  final String? description;
  final String? canHelp;
  final String? lookingFor;
  final String? website;
  final String? instagram;
  final int? employeesCount;

  /// Что из профиля сейчас видно другим резидентам. Ключи — как на
  /// сервере: `description`, `can_help`, `looking_for`, `employees_count`,
  /// `website`, `instagram`, `contacts`.
  final Map<String, bool> visibility;

  /// Поле, о котором сервер промолчал, считаем скрытым: показать лишнее
  /// хуже, чем не показать.
  bool shows(String field) => visibility[field] ?? false;

  factory ResidentProfile.fromJson(Map<String, dynamic> json) =>
      ResidentProfile(
        businessName: json['business_name'] as String?,
        niche: json['niche'] as String?,
        description: json['description'] as String?,
        canHelp: json['can_help'] as String?,
        lookingFor: json['looking_for'] as String?,
        website: json['website'] as String?,
        instagram: json['instagram'] as String?,
        employeesCount: (json['employees_count'] as num?)?.toInt(),
        visibility: _flags(json['visibility']),
      );
}

class Resident {
  const Resident({
    required this.id,
    required this.name,
    required this.phone,
    required this.cardNumber,
    required this.isClubMember,
    required this.memberships,
    this.phonePretty,
    this.city,
    this.telegram,
    this.whatsapp,
    this.birthdate,
    this.avatarUrl,
    this.tierLabel,
    this.profile,
    this.feeReminder,
  });

  final int id;
  final String name;
  final String phone;
  final String? phonePretty;
  final String? city;
  final String? telegram;
  final String? whatsapp;
  final DateTime? birthdate;
  final String? avatarUrl;
  final String cardNumber;
  final String? tierLabel;
  final bool isClubMember;
  final List<Membership> memberships;
  final ResidentProfile? profile;

  /// null — напоминать о взносе не нужно.
  final FeeReminder? feeReminder;

  /// Ближайший долг по взносу — из него собирается плашка на главной.
  Membership? get overdueMembership {
    for (final m in memberships) {
      if (m.isOverdue) return m;
    }
    return null;
  }

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

  factory Resident.fromJson(Map<String, dynamic> json) => Resident(
    id: _toInt(json['id']),
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    phonePretty: json['phone_pretty'] as String?,
    city: json['city'] as String?,
    telegram: json['telegram'] as String?,
    whatsapp: json['whatsapp'] as String?,
    birthdate: json['birthdate'] != null
        ? DateTime.tryParse(json['birthdate'] as String)
        : null,
    avatarUrl: json['avatar_url'] as String?,
    cardNumber: json['card_number'] as String? ?? '',
    tierLabel: json['tier_label'] as String?,
    isClubMember: json['is_club_member'] as bool? ?? false,
    memberships: (json['memberships'] as List<dynamic>? ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList(),
    profile: json['profile'] is Map<String, dynamic>
        ? ResidentProfile.fromJson(json['profile'] as Map<String, dynamic>)
        : null,
    feeReminder: json['fee_reminder'] is Map<String, dynamic>
        ? FeeReminder.fromJson(json['fee_reminder'] as Map<String, dynamic>)
        : null,
  );
}

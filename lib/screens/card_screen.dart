import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/directory.dart';
import '../models/resident.dart';
import '../state/auth_controller.dart';
import '../state/directory_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_qr_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'partner_detail_screen.dart';

/// Карта резидента (раздел 23): цифровая карта, живой QR и привилегии.
///
/// Привилегии живут здесь, а не отдельным разделом: карта — это и есть
/// то, что резидент показывает партнёру, и список того, что ему положено,
/// должен быть под рукой в тот же момент.
///
/// QR живёт `expires_in` секунд и обновляется сам. Статический код
/// превратил бы скриншот в вечный пропуск на мероприятия и чужую скидку
/// у партнёра, поэтому токен ротируется, а просроченный — не показывается.
class ResidentCardScreen extends StatefulWidget {
  const ResidentCardScreen({super.key});

  @override
  State<ResidentCardScreen> createState() => _ResidentCardScreenState();
}

class _ResidentCardScreenState extends State<ResidentCardScreen> {
  String? _token;
  int _secondsLeft = 0;
  int _totalSeconds = 0;
  Timer? _ticker;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshToken();
    // Карту открывают и с главной, минуя «Клуб» — привилегии могут быть
    // ещё не загружены
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DirectoryController>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshToken() async {
    // Тикер глушим на время запроса: иначе на медленной сети он продолжит
    // дёргать refresh каждую секунду и запросы наслоятся друг на друга.
    _ticker?.cancel();

    setState(() {
      _error = null;
      // Скелет — только когда показывать нечего. При плановой ротации
      // старый QR ещё валиден пару секунд, и мигать карточкой незачем.
      if (_token == null) _loading = true;
    });

    try {
      final api = context.read<ApiClient>();
      final response = await api.get('/me/card');

      if (!mounted) return;

      final token = response['qr_token'] as String?;
      if (token == null) {
        // Сервер ответил без токена — для пользователя это та же ошибка
        // загрузки, показываем «Повторить», а не пустой квадрат.
        setState(() {
          _token = null;
          _error = 'Не удалось загрузить QR-код';
          _loading = false;
        });
        return;
      }

      setState(() {
        _token = token;
        _secondsLeft = (response['expires_in'] as num?)?.toInt() ?? 60;
        _totalSeconds = _secondsLeft;
        _loading = false;
      });

      _startTicker();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // Просроченный токен убираем: экран не должен продолжать
        // показывать QR, который сканер уже не примет (Security, раздел 23).
        _token = null;
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_secondsLeft <= 1) {
        _refreshToken();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resident = context.watch<AuthController>().resident;
    final directory = context.watch<DirectoryController>();

    return DSubScaffold(
      title: 'Карта резидента',
      pattern: false,
      children: [
        if (resident != null) ...[
          _DigitalCard(resident: resident),
          const SizedBox(height: DSpace.section),
        ],
        if (_loading)
          const DSkeletonCard(lines: 3)
        else if (_error != null)
          DErrorState(message: _error!, onRetry: _refreshToken)
        else if (_token != null)
          _QrBlock(
            token: _token!,
            secondsLeft: _secondsLeft,
            totalSeconds: _totalSeconds,
          ),
        const SizedBox(height: DSpace.section),
        _PrivilegesSection(controller: directory),
      ],
    );
  }
}

/// Что положено по карте. Новая привилегия — от партнёра или от резидента —
/// появляется здесь сама, как только организатор её завёл.
class _PrivilegesSection extends StatelessWidget {
  const _PrivilegesSection({required this.controller});

  final DirectoryController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rows = _offerRows(c.partners);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DSectionLabel('Привилегии'),
        const SizedBox(height: DSpace.sm),

        if (c.loading && c.partners.isEmpty)
          const DSkeletonCard(lines: 2)
        else if (c.partners.isEmpty)
          const DEmptyState(title: 'Активных предложений пока нет')
        else ...[
          _SavingsCard(offersCount: rows.length, savings: c.savings),
          const SizedBox(height: DSpace.md),
          DBrandCard(
            padding: const EdgeInsets.symmetric(
              horizontal: DSpace.md,
              vertical: DSpace.xs,
            ),
            child: Column(
              children: [
                // Строка на каждую привилегию, а не на партнёра: у партнёра
                // с несколькими офферами каждый должен быть достижим из списка
                for (final (i, row) in rows.indexed) ...[
                  _PartnerRow(partner: row.$1, offer: row.$2),
                  if (i < rows.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Счётчик предложений и накопитель экономии. Заявленную и подтверждённую
/// суммы показываем раздельно, но KPI-акцент — только на подтверждённой:
/// это правило бэкенда, интерфейс его лишь отражает (раздел 22).
class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.offersCount, required this.savings});

  final int offersCount;
  final Savings savings;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.plural(
              offersCount,
              'активное предложение',
              'активных предложения',
              'активных предложений',
            ),
            style: DText.of(context).cardTitle,
          ),
          if (savings.count > 0) ...[
            const SizedBox(height: DSpace.md),
            const Divider(),
            const SizedBox(height: DSpace.md),
            _SavingsLine(
              label: 'Заявлено резидентом',
              value: savings.total,
              emphasized: false,
            ),
            const SizedBox(height: DSpace.xs),
            _SavingsLine(
              label: 'Подтверждено клубом',
              value: savings.confirmed,
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SavingsLine extends StatelessWidget {
  const _SavingsLine({
    required this.label,
    required this.value,
    required this.emphasized,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    return Row(
      children: [
        Expanded(child: Text(label, style: t.bodyMuted)),
        Text(
          Fmt.metric(value.toDouble(), '₽'),
          style: emphasized
              ? t.kpi.copyWith(color: c.accent)
              : t.body.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Пары «партнёр — привилегия» для плоского списка.
List<(Partner, PartnerOffer)> _offerRows(List<Partner> partners) => [
  for (final p in partners)
    for (final o in p.offers) (p, o),
];

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({required this.partner, required this.offer});

  final Partner partner;
  final PartnerOffer offer;

  @override
  Widget build(BuildContext context) {
    final resident = partner.resident;

    return DListRow(
      title: partner.name,
      // «Свою» привилегию подписываем именем резидента: так видно,
      // что это предложение изнутри клуба, а не внешняя скидка
      subtitle: resident == null
          ? offer.title
          : '${offer.title} · ${resident.name}',
      leading: resident == null
          ? null
          : DUserAvatar(name: resident.name, photoUrl: resident.avatarUrl),
      trailing: DStatusChip(
        offer.benefit,
        tone: offer.isAvailable ? DChipTone.green : DChipTone.outline,
      ),
      chevron: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PartnerOfferDetailScreen(partner: partner, offer: offer),
        ),
      ),
    );
  }
}

/// Блок 1 — цифровая карта: знак, имя, уровень, номер, срок действия.
class _DigitalCard extends StatelessWidget {
  const _DigitalCard({required this.resident});

  final Resident resident;

  /// Карта действует, пока действует членство. У клубного резидента
  /// определяющий взнос — клубный (он включает экосистему), иначе берём
  /// первый, у которого отмечена оплата.
  DateTime? get _validUntil {
    for (final m in resident.memberships) {
      if (m.isClub && m.paidUntil != null) return m.paidUntil;
    }
    for (final m in resident.memberships) {
      if (m.paidUntil != null) return m.paidUntil;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final validUntil = _validUntil;

    return DBrandCard(
      background: DColors.of(context).surface2,
      radius: DRadius.cardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resident.name, style: DText.of(context).cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      resident.tierLabel ?? 'Резидент',
                      style: DText.of(
                        context,
                      ).caption.copyWith(color: DColors.of(context).accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.md),
              // Монохромный знак из брендбука тонируется акцентом —
              // логотип не перерисован и не искажён (раздел 3).
              Image.asset(
                'assets/brand/logo_mark.png',
                width: 30,
                height: 30,
                color: DColors.of(context).accent,
                colorBlendMode: BlendMode.srcIn,
              ),
            ],
          ),
          const SizedBox(height: DSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _CardField(
                  label: 'Номер карты',
                  value: resident.cardNumber.isEmpty
                      ? '—'
                      : resident.cardNumber,
                ),
              ),
              if (validUntil != null)
                _CardField(
                  label: 'Действует до',
                  value: Fmt.date(validUntil),
                  alignEnd: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        DSectionLabel(label),
        const SizedBox(height: DSpace.xs),
        Text(
          value,
          style: DText.of(
            context,
          ).kpi.copyWith(fontSize: 16, letterSpacing: 0.4),
        ),
      ],
    );
  }
}

/// Блок 2 — живой QR с тонкой линией отсчёта до ротации.
class _QrBlock extends StatelessWidget {
  const _QrBlock({
    required this.token,
    required this.secondsLeft,
    required this.totalSeconds,
  });

  final String token;
  final int secondsLeft;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: DQrCard(
            data: token,
            size: 220,
            caption: 'QR обновляется автоматически',
          ),
        ),
        const SizedBox(height: DSpace.md),
        Center(
          // Линия сужена до ширины QR-панели: полноэкранная полоса
          // спорила бы с главным объектом экрана.
          child: SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                // Спокойный отсчёт без цифр: секундомер на экране
                // спецификация запрещает, достаточно убывающей линии.
                value: totalSeconds > 0 ? secondsLeft / totalSeconds : 0,
                minHeight: 3,
                color: DColors.of(context).accent,
                backgroundColor: DColors.of(context).surface3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/club_time.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event_proposal.dart';
import '../state/events_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_filter_chip.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_sub_scaffold.dart';

/// Резидент предлагает своё мероприятие. В афишу оно попадёт,
/// только когда организаторы его посмотрят и опубликуют.
class EventProposalScreen extends StatefulWidget {
  const EventProposalScreen({super.key, this.initialDate});

  /// День, выбранный в календаре, — чтобы не выбирать его второй раз.
  final DateTime? initialDate;

  @override
  State<EventProposalScreen> createState() => _EventProposalScreenState();
}

class _EventProposalScreenState extends State<EventProposalScreen> {
  static const _types = [
    ('breakfast', 'Бизнес-завтрак'),
    ('seminar', 'Семинар'),
    ('forum', 'Бизнес-форум'),
    ('sprint', 'Бизнес-спринт'),
    ('trip', 'Бизнес-поездка'),
    ('other', 'Другое'),
  ];

  static const _formats = [
    ('offline', 'Очно'),
    ('online', 'Онлайн'),
    ('hybrid', 'Очно и онлайн'),
  ];

  /// Поля, у которых замечание сервера показывается на месте.
  static const _fieldsOnScreen = {
    'title',
    'starts_at',
    'ends_at',
    'capacity',
    'place',
    'address',
    'topic',
    'description',
  };

  static final _dateLabel = DateFormat('d MMMM y, EEEE', 'ru_RU');

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _topic = TextEditingController();
  final _place = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController();
  final _description = TextEditingController();

  String _type = 'other';
  String _format = 'offline';
  DateTime? _date;

  /// Большинство встреч клуба — вечером; время легко поменять.
  TimeOfDay _start = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay? _end;

  String? _dateError;
  String? _endError;
  Map<String, List<String>> _serverErrors = const {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate;
    if (initial != null) _date = DateUtils.dateOnly(initial);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _topic,
      _place,
      _address,
      _capacity,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _server(String field) => _serverErrors[field]?.first;

  Future<void> _pickDate() async {
    // Календарь работает с датами без часов — берём московское число
    final moscow = ClubTime.today();
    final today = DateTime(moscow.year, moscow.month, moscow.day);
    final last = DateTime(today.year + 2, today.month, today.day);
    final current = _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(today)
          ? today
          : (current.isAfter(last) ? last : current),
      firstDate: today,
      lastDate: last,
      locale: const Locale('ru'),
    );

    if (picked != null) {
      setState(() {
        _date = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _pickTime({required bool end}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: end
          ? (_end ?? _start.replacing(hour: (_start.hour + 2) % 24))
          : _start,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null) return;

    setState(() {
      if (end) {
        _end = picked;
      } else {
        _start = picked;
      }
      _endError = null;
      _dateError = null;
    });
  }

  /// Московское время «как на стене» — в тех же полях, что у мероприятий.
  DateTime _at(DateTime day, TimeOfDay time) =>
      DateTime.utc(day.year, day.month, day.day, time.hour, time.minute);

  Future<void> _submit() async {
    if (_sending) return;

    final formOk = _formKey.currentState?.validate() ?? false;
    final date = _date;
    final startsAt = date == null ? null : _at(date, _start);
    final end = _end;
    final endsAt = date == null || end == null ? null : _at(date, end);

    setState(() {
      _serverErrors = const {};
      _dateError = switch (startsAt) {
        null => 'Выберите дату',
        final at when !at.isAfter(ClubTime.now()) => 'Это время уже прошло',
        _ => null,
      };
      _endError =
          startsAt != null && endsAt != null && !endsAt.isAfter(startsAt)
          ? 'Окончание должно быть позже начала'
          : null;
    });

    if (!formOk ||
        startsAt == null ||
        _dateError != null ||
        _endError != null) {
      return;
    }

    setState(() => _sending = true);

    // Берём всё нужное до асинхронной паузы: после неё экран может закрыться
    final events = context.read<EventsController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await events.propose(
        EventProposalDraft(
          title: _title.text,
          type: _type,
          format: _format,
          startsAt: startsAt,
          endsAt: endsAt,
          topic: _topic.text,
          description: _description.text,
          place: _place.text,
          address: _address.text,
          capacity: int.tryParse(_capacity.text.trim()),
        ),
      );

      if (!mounted) return;
      await navigator.maybePop(true);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _serverErrors = e.fieldErrors;
        _dateError = _server('starts_at') ?? _dateError;
        _endError = _server('ends_at') ?? _endError;
      });

      // Замечание к полю видно у поля; остальное — внизу экрана
      if (!e.fieldErrors.keys.every(_fieldsOnScreen.contains) ||
          e.fieldErrors.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      // Экран остался открытым — кнопка снова должна нажиматься
      if (mounted && _sending) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final end = _end;

    return Form(
      key: _formKey,
      child: DSubScaffold(
        title: 'Предложить мероприятие',
        subtitle:
            'Организаторы посмотрят заявку и опубликуют мероприятие в афише. '
            'Решение появится в «Мои предложения».',
        children: [
          TextFormField(
            controller: _title,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Название',
              hintText: 'Разбор воронок продаж',
              counterText: '',
              errorText: _server('title'),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Напишите название' : null,
          ),
          const SizedBox(height: DSpace.md),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Вид'),
            items: [
              for (final (value, label) in _types)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Формат'),
          const SizedBox(height: DSpace.sm),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (value, label) in _formats)
                  DFilterChip(
                    label: label,
                    selected: _format == value,
                    onTap: () => setState(() => _format = value),
                  ),
              ],
            ),
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Когда'),
          const SizedBox(height: DSpace.sm),
          _PickTile(
            icon: Icons.event_outlined,
            label: 'Дата',
            value: date == null ? null : _dateLabel.format(date),
            placeholder: 'Выберите дату',
            error: _dateError,
            onTap: _pickDate,
          ),
          const SizedBox(height: DSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PickTile(
                  icon: Icons.schedule,
                  label: 'Начало',
                  value: _start.format24(),
                  onTap: () => _pickTime(end: false),
                ),
              ),
              const SizedBox(width: DSpace.sm),
              Expanded(
                child: _PickTile(
                  icon: Icons.schedule,
                  label: 'Окончание',
                  value: end?.format24(),
                  placeholder: 'Не указано',
                  error: _endError,
                  onTap: () => _pickTime(end: true),
                  onClear: end == null
                      ? null
                      : () => setState(() {
                          _end = null;
                          _endError = null;
                        }),
                ),
              ),
            ],
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Где и для кого'),
          const SizedBox(height: DSpace.sm),
          TextFormField(
            controller: _place,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Место',
              hintText: 'Офис экосистемы',
              counterText: '',
              errorText: _server('place'),
            ),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            controller: _address,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Адрес',
              counterText: '',
              errorText: _server('address'),
            ),
          ),
          const SizedBox(height: DSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _topic,
                  maxLength: 64,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Тема',
                    hintText: 'Маркетинг',
                    counterText: '',
                    errorText: _server('topic'),
                  ),
                ),
              ),
              const SizedBox(width: DSpace.sm),
              Expanded(
                child: TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Сколько мест',
                    hintText: 'Без ограничения',
                    errorText: _server('capacity'),
                  ),
                  validator: _capacityError,
                ),
              ),
            ],
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Описание',
              hintText: 'О чём встреча и кому она будет полезна',
              alignLabelWithHint: true,
              errorText: _server('description'),
            ),
          ),

          // Кнопка — последней строкой формы: уезжает вместе с ней
          // и не висит над клавиатурой, закрывая поля
          const SizedBox(height: DSpace.xl),
          DPrimaryButton(
            label: 'Отправить организаторам',
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  String? _capacityError(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final n = int.tryParse(text);
    return n == null || n < 1 || n > 10000 ? 'От 1 до 10 000' : null;
  }
}

extension on TimeOfDay {
  String format24() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Плитка выбора даты или времени — как срок в форме цели.
class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.error,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final String? error;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);
    final shown = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DBrandCard(
          onTap: onTap,
          borderColor: error == null ? null : c.danger,
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.md,
            vertical: DSpace.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: c.accent, size: 20),
              const SizedBox(width: DSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.caption),
                    const SizedBox(height: 2),
                    Text(
                      shown ?? placeholder ?? '',
                      style: shown == null
                          ? t.bodyMuted
                          : t.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Убрать',
                  color: c.textTertiary,
                ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: DSpace.xs),
          Text(error!, style: t.caption.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}

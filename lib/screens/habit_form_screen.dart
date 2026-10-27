import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/habit.dart';
import '../state/habits_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_filter_chip.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_sub_scaffold.dart';
import 'habits_catalog_screen.dart';

/// Новая привычка или правка своей. Пока человек пишет название,
/// подсказываем похожие общие привычки клуба: присоединиться к ним
/// лучше, чем заводить такую же отдельно.
class HabitFormScreen extends StatefulWidget {
  const HabitFormScreen({super.key, this.habit});

  /// Своя привычка, которую ещё никто не ведёт вместе с автором.
  final Habit? habit;

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  static const _weekdays = [1, 2, 3, 4, 5];
  static const _everyDay = [1, 2, 3, 4, 5, 6, 7];

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.habit?.title);
  late final _unit = TextEditingController(text: widget.habit?.unit);
  late final _target = TextEditingController(
    text: '${widget.habit?.target ?? 1}',
  );
  late Set<int> _days = {...(widget.habit?.days ?? _everyDay)};
  late bool _public = widget.habit?.isPublic ?? false;

  Timer? _debounce;
  List<ListedHabit> _similar = const [];
  String? _daysError;
  Map<String, List<String>> _serverErrors = const {};
  bool _saving = false;

  bool get _editing => widget.habit != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _unit.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Похожие ищем с задержкой: не на каждую букву.
  void _onTitleChanged(String value) {
    if (_editing) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final text = value.trim();
      if (text.length < 3) {
        if (mounted) setState(() => _similar = const []);
        return;
      }

      try {
        final similar = await context.read<HabitsController>().suggest(text);
        // Пока ждали ответа, название могли переписать — старый ответ не нужен
        if (mounted && _title.text.trim() == text) {
          setState(() => _similar = similar);
        }
      } on ApiException {
        // Подсказка — не главное: без неё форма работает как обычно
      }
    });
  }

  void _setDays(Iterable<int> days) => setState(() {
    _days = {...days};
    _daysError = null;
  });

  void _toggleDay(int day) => setState(() {
    _days = _days.contains(day) ? ({..._days}..remove(day)) : {..._days, day};
    _daysError = null;
  });

  Future<void> _save() async {
    if (_saving) return;

    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _serverErrors = const {};
      _daysError = _days.isEmpty ? 'Выберите хотя бы один день' : null;
    });
    if (!formOk || _days.isEmpty) return;

    setState(() => _saving = true);

    final habits = context.read<HabitsController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = HabitDraft(
      title: _title.text,
      unit: _unit.text,
      target: int.parse(_target.text.trim()),
      days: _days.toList()..sort(),
      isPublic: _public,
    );

    try {
      final habit = widget.habit;
      if (habit == null) {
        await habits.create(draft);
      } else {
        await habits.update(habit.id, draft.toJson());
      }

      if (mounted) await navigator.maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.fieldErrors);
      if (e.fieldErrors.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _server(String field) => _serverErrors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);
    final days = _days.toList()..sort();

    return Form(
      key: _formKey,
      child: DSubScaffold(
        title: _editing ? 'Правка привычки' : 'Новая привычка',
        children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _onTitleChanged,
            decoration: InputDecoration(
              labelText: 'Что делаете',
              hintText: 'Например, гулять перед сном',
              counterText: '',
              errorText: _server('title'),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Напишите, что делаете' : null,
          ),

          if (_similar.isNotEmpty) ...[
            const SizedBox(height: DSpace.section),
            const DSectionLabel('Похожие уже ведут в клубе'),
            const SizedBox(height: DSpace.sm),
            DRowsCard(
              children: [
                for (final s in _similar)
                  DListRow(
                    title: s.title,
                    subtitle: '${s.norm} · ведут ${s.participantsCount}',
                    trailing: TextButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        if (await joinHabit(context, s) && mounted) {
                          await navigator.maybePop();
                        }
                      },
                      child: const Text('Присоединиться'),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: DSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Норма',
                    errorText: _server('target'),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1 || n > 100000
                        ? 'От 1 до 100 000'
                        : null;
                  },
                ),
              ),
              const SizedBox(width: DSpace.sm),
              Expanded(
                child: TextFormField(
                  controller: _unit,
                  maxLength: 32,
                  decoration: InputDecoration(
                    labelText: 'Единица',
                    hintText: 'страниц, км',
                    counterText: '',
                    errorText: _server('unit'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            'Без единицы и с нормой 1 — просто отметка «сделал».',
            style: t.caption,
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('По каким дням'),
          const SizedBox(height: DSpace.sm),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                DFilterChip(
                  label: 'Каждый день',
                  selected: days.length == 7,
                  onTap: () => _setDays(_everyDay),
                ),
                DFilterChip(
                  label: 'По будням',
                  selected: days.join(',') == _weekdays.join(','),
                  onTap: () => _setDays(_weekdays),
                ),
              ],
            ),
          ),
          const SizedBox(height: DSpace.sm),
          Wrap(
            spacing: 0,
            runSpacing: DSpace.sm,
            children: [
              for (var d = 1; d <= 7; d++)
                SizedBox(
                  height: 44,
                  child: DFilterChip(
                    label: HabitDays.short[d - 1],
                    selected: _days.contains(d),
                    onTap: () => _toggleDay(d),
                  ),
                ),
            ],
          ),
          if (_daysError != null) ...[
            const SizedBox(height: DSpace.xs),
            Text(_daysError!, style: t.caption.copyWith(color: c.danger)),
          ],

          const SizedBox(height: DSpace.section),
          MergeSemantics(
            child: DBrandCard(
              onTap: () => setState(() => _public = !_public),
              padding: const EdgeInsets.symmetric(
                horizontal: DSpace.lg,
                vertical: DSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Видна всему клубу',
                          style: t.body.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Другие смогут присоединиться со своей нормой, '
                          'а вы попадёте в рейтинг стабильности',
                          style: t.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DSpace.sm),
                  Switch(
                    value: _public,
                    onChanged: (v) => setState(() => _public = v),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка — последней строкой формы: уезжает вместе с ней
          const SizedBox(height: DSpace.xl),
          DPrimaryButton(
            label: _editing ? 'Сохранить' : 'Сохранить привычку',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

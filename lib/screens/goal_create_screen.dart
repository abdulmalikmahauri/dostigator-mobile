import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/reminders.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/goal.dart';
import '../state/goals_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_sub_scaffold.dart';

/// Постановка цели и её правка — одна форма.
///
/// Метрика обязательна: без числа «было → станет» цель не измерить,
/// а чек-ин превращается в переписку о самочувствии.
class GoalCreateScreen extends StatefulWidget {
  const GoalCreateScreen({super.key, this.goal});

  /// Цель на правку. Без неё экран ставит новую.
  final Goal? goal;

  @override
  State<GoalCreateScreen> createState() => _GoalCreateScreenState();
}

/// Строка шага в форме: поле ввода и номер шага на сервере, если он
/// уже сохранён. Номер нужен, чтобы правка не стёрла отметку «сделано».
class _StepField {
  _StepField({this.id, String text = ''})
    : controller = TextEditingController(text: text);

  final int? id;
  final TextEditingController controller;
}

class _GoalCreateScreenState extends State<GoalCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _why = TextEditingController();
  final _metricName = TextEditingController();
  final _metricUnit = TextEditingController();
  final _from = TextEditingController();
  final _target = TextEditingController();
  final _steps = <_StepField>[];

  /// Срок — любой: от завтрашнего дня до нескольких лет вперёд.
  static const _latestDeadline = Duration(days: 365 * 5);

  late DateTime _deadline;
  bool _hideValues = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.goal != null;

  /// Три месяца — срок, на который проще всего удержать внимание.
  /// Это только подсказка: дату можно выбрать любую.
  static DateTime _defaultDeadline(DateTime now) {
    return DateTime(now.year, now.month + 3, now.day);
  }

  @override
  void initState() {
    super.initState();

    final goal = widget.goal;

    if (goal == null) {
      _deadline = _defaultDeadline(DateTime.now());
      _steps.add(_StepField());

      return;
    }

    _title.text = goal.title;
    _why.text = goal.why ?? '';
    _metricName.text = goal.metricName;
    _metricUnit.text = goal.metricUnit ?? '';
    _from.text = _plain(goal.metricFrom);
    _target.text = _plain(goal.metricTarget);
    _deadline = goal.deadline;
    _hideValues = goal.hideAbsoluteValues;

    _steps.addAll(goal.steps.map((s) => _StepField(id: s.id, text: s.title)));
    if (_steps.isEmpty) _steps.add(_StepField());
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _why,
      _metricName,
      _metricUnit,
      _from,
      _target,
      ..._steps.map((s) => s.controller),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Число без хвоста «.0»: в поле оно должно выглядеть так, как его ввели.
  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.').replaceAll(' ', ''));

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final first = now.add(const Duration(days: 1));
    final last = now.add(_latestDeadline);

    final picked = await showDatePicker(
      context: context,
      // У просроченной цели прежний срок позади — календарь его не покажет
      initialDate: _deadline.isBefore(first)
          ? first
          : (_deadline.isAfter(last) ? last : _deadline),
      firstDate: first,
      lastDate: last,
      locale: const Locale('ru'),
    );

    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final from = _num(_from);
    final target = _num(_target);
    // Проверка формы уже отсеяла пустые числа; это страховка, а не логика
    if (from == null || target == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // Берём контроллер до первой асинхронной паузы: после неё виджет
    // может быть уже снят, и обращаться к context нельзя.
    final goals = context.read<GoalsController>();
    final goal = widget.goal;

    final error = goal == null
        ? await goals.create(
            title: _title.text.trim(),
            why: _why.text.trim(),
            metricName: _metricName.text.trim(),
            metricUnit: _metricUnit.text.trim(),
            from: from,
            target: target,
            deadline: _deadline,
            steps: _steps.map((s) => s.controller.text).toList(),
            hideAbsoluteValues: _hideValues,
          )
        : await goals.update(
            goalId: goal.id,
            title: _title.text.trim(),
            why: _why.text.trim(),
            metricName: _metricName.text.trim(),
            metricUnit: _metricUnit.text.trim(),
            from: from,
            target: target,
            deadline: _deadline,
            steps: [
              for (final s in _steps)
                GoalStepDraft(id: s.id, title: s.controller.text),
            ],
            hideAbsoluteValues: _hideValues,
          );

    if (!mounted) return;

    if (error != null) {
      // Форма остаётся заполненной: резидент правит одно поле,
      // а не набирает цель заново.
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    if (goal == null) {
      // Разрешение спрашиваем здесь, а не на старте приложения: в этот
      // момент человек только что поставил цель, и связь «напоминание —
      // моя цель» очевидна. Отказ ничего не ломает: приложение работает
      // как прежде, просто без еженедельного напоминания.
      //
      // Цель к этому моменту уже создана. Если служба уведомлений на этом
      // телефоне сломана, экран всё равно обязан закрыться — иначе человек
      // нажмёт «Сохранить» ещё раз и получит вторую такую же цель.
      try {
        if (!await Reminders.isGranted()) {
          await Reminders.requestPermission();
        }
      } on Exception catch (e) {
        debugPrint('Разрешение на напоминания не получено: $e');
      }

      // Перечитываем цели: внутри load() расписание напоминаний
      // приводится в соответствие с только что созданной целью.
      await goals.load(silent: true);
    }

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  /// Завершить цель: взята или больше не актуальна. Удаления нет —
  /// закрытая цель уходит в архив вместе со своей историей.
  Future<void> _finish(Goal goal) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Цель достигнута'),
              subtitle: const Text('Уйдёт в архив как взятая'),
              onTap: () => Navigator.of(context).pop('achieved'),
            ),
            ListTile(
              leading: const Icon(Icons.do_not_disturb_alt_outlined),
              title: const Text('Больше не актуальна'),
              subtitle: const Text('Уйдёт в архив без результата'),
              onTap: () => Navigator.of(context).pop('dropped'),
            ),
            const SizedBox(height: DSpace.sm),
          ],
        ),
      ),
    );

    if (status == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await context.read<GoalsController>().close(goal.id, status);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  /// Живая подсказка «было → станет» в фирменном формате: резидент сразу
  /// видит, как цель будет выглядеть на карточке, и замечает лишний ноль.
  String? get _metricPreview {
    final from = _num(_from);
    final target = _num(_target);
    if (from == null || target == null) return null;

    final unit = _metricUnit.text.trim();
    return '${Fmt.metric(from, unit)} → ${Fmt.metric(target, unit)}';
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final preview = _metricPreview;
    final error = _error;

    return Form(
      key: _formKey,
      child: DSubScaffold(
        title: _editing ? 'Правка цели' : 'Новая цель',
        children: [
          TextFormField(
            key: const Key('goal-title'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название цели',
              hintText: 'Увеличить оборот компании',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Сформулируйте цель' : null,
          ),
          const SizedBox(height: DSpace.md),

          TextFormField(
            key: const Key('goal-why'),
            controller: _why,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Зачем это вам',
              hintText:
                  'Необязательно, но помогает не бросить '
                  'на третьей неделе',
            ),
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Чем измеряем'),
          const SizedBox(height: DSpace.sm),

          TextFormField(
            key: const Key('metric-name'),
            controller: _metricName,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Показатель',
              hintText: 'Чистая прибыль в месяц',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Укажите показатель' : null,
          ),
          const SizedBox(height: DSpace.md),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('metric-from'),
                  controller: _from,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]')),
                  ],
                  // У цели в работе это точка отсчёта, а не сегодняшнее значение
                  decoration: InputDecoration(
                    labelText: _editing ? 'Было' : 'Сейчас',
                  ),
                  validator: (_) => _num(_from) == null ? 'Число' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: DSpace.sm),
              Expanded(
                child: TextFormField(
                  key: const Key('metric-target'),
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Станет'),
                  validator: (_) {
                    final target = _num(_target);
                    if (target == null) return 'Число';
                    if (target == _num(_from)) return 'Должно отличаться';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: DSpace.sm),
              SizedBox(
                width: 78,
                child: TextFormField(
                  key: const Key('metric-unit'),
                  controller: _metricUnit,
                  decoration: const InputDecoration(
                    labelText: 'Ед.',
                    hintText: '₽',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          if (preview != null) ...[
            const SizedBox(height: DSpace.sm),
            Text(preview, style: DText.of(context).kpi),
          ],

          const SizedBox(height: DSpace.md),
          _DeadlineTile(deadline: _deadline, onTap: _pickDeadline),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Шаги к цели'),
          const SizedBox(height: DSpace.xs),
          Text(
            'Конкретные действия — сколько нужно. '
            'Их можно будет отмечать по ходу.',
            style: DText.of(context).caption,
          ),
          const SizedBox(height: DSpace.sm),

          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: DSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: Key('step-$i'),
                      controller: _steps[i].controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: 'Шаг ${i + 1}'),
                    ),
                  ),
                  if (_steps.length > 1)
                    IconButton(
                      key: Key('remove-step-$i'),
                      onPressed: () => setState(
                        () => _steps.removeAt(i).controller.dispose(),
                      ),
                      tooltip: 'Удалить шаг',
                      icon: Icon(
                        Icons.close,
                        color: DColors.of(context).textTertiary,
                      ),
                    ),
                ],
              ),
            ),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-step'),
              onPressed: () => setState(() => _steps.add(_StepField())),
              // Touch-цель не меньше 44px — у TextButton по умолчанию ниже.
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить шаг'),
            ),
          ),

          const SizedBox(height: DSpace.md),
          _PrivacyToggle(
            value: _hideValues,
            onChanged: (v) => setState(() => _hideValues = v),
          ),

          // Кнопка — последней строкой формы: она уезжает вместе с ней
          // и не висит над клавиатурой, закрывая поля
          const SizedBox(height: DSpace.xl),
          if (error != null) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: DColors.of(context).danger,
                ),
                const SizedBox(width: DSpace.sm),
                Expanded(
                  child: Text(
                    error,
                    style: DText.of(
                      context,
                    ).caption.copyWith(color: DColors.of(context).danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DSpace.sm),
          ],
          DPrimaryButton(
            label: _editing ? 'Сохранить' : 'Сохранить цель',
            loading: _saving,
            onPressed: _save,
          ),
          if (goal != null) ...[
            const SizedBox(height: DSpace.xs),
            TextButton(
              onPressed: _saving ? null : () => _finish(goal),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Завершить цель'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.deadline, required this.onTap});

  final DateTime deadline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = deadline.difference(DateTime.now()).inDays;

    return DBrandCard(
      key: const Key('deadline-tile'),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.lg,
        vertical: DSpace.md,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            color: DColors.of(context).accent,
            size: 20,
          ),
          const SizedBox(width: DSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Срок', style: DText.of(context).caption),
                const SizedBox(height: 2),
                Text(Fmt.date(deadline), style: DText.of(context).cardTitle),
              ],
            ),
          ),
          Text(
            // У просроченной цели считать «минус дни» незачем
            days < 0 ? 'срок вышел' : Fmt.plural(days, 'день', 'дня', 'дней'),
            style: DText.of(context).caption,
          ),
          const SizedBox(width: DSpace.sm),
          Icon(Icons.chevron_right, color: DColors.of(context).textTertiary),
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      onTap: () => onChanged(!value),
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
                  'Скрыть абсолютные значения от участников',
                  style: DText.of(
                    context,
                  ).body.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Группа увидит только процент выполнения, без сумм',
                  style: DText.of(context).caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: DSpace.sm),
          Switch(
            key: const Key('privacy-toggle'),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

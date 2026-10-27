import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/goal.dart';
import '../state/goals_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_sub_scaffold.dart';

/// Weekly check-in (раздел 15 спецификации). Заполнение должно занимать
/// около 30 секунд: значение метрики, одна строка о неделе, флаг «нужна
/// помощь» — и всё. Любое лишнее поле снижает частоту отчётов.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, this.goal});

  /// Цель, по которой отчёт. Целей в работе может быть несколько, поэтому
  /// экраны передают её явно; без неё берём главную.
  final Goal? goal;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  /// Маркер, которым текст помощи приклеивается к комментарию:
  /// API принимает только comment + needs_help, контракт не меняем.
  static const _helpMarker = 'Нужна помощь: ';

  final _value = TextEditingController();
  final _comment = TextEditingController();
  final _help = TextEditingController();

  bool _needsHelp = false;
  bool _saving = false;
  bool _prefilled = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final goal = _resolve(context.read<GoalsController>());
    if (goal != null) _prefill(goal);
  }

  /// Свежая версия цели из контроллера: переданная могла устареть,
  /// если с момента открытия экрана список перечитали.
  Goal? _resolve(GoalsController controller) {
    final passed = widget.goal;
    if (passed == null) return controller.mainGoal;

    return controller.byId(passed.id) ?? passed;
  }

  @override
  void dispose() {
    _value.dispose();
    _comment.dispose();
    _help.dispose();
    super.dispose();
  }

  /// Подставляем последнее известное значение: чаще всего его нужно
  /// немного подвинуть, а не вводить с нуля. Если чек-ин этой недели уже
  /// есть — редактируем его, а не начинаем с пустой формы.
  void _prefill(Goal goal) {
    _prefilled = true;
    _value.text = _plain(goal.metricCurrent);

    final current = _currentWeekCheckin(goal);
    if (current == null) return;

    _value.text = _plain(current.metricValue);
    _needsHelp = current.needsHelp;

    // Комментарий мог быть склеен с текстом помощи — разбираем обратно,
    // чтобы при редактировании каждая часть попала в своё поле.
    final comment = current.comment ?? '';
    final markerAt = comment.indexOf('\n$_helpMarker');
    if (markerAt >= 0) {
      _comment.text = comment.substring(0, markerAt);
      _help.text = comment.substring(markerAt + 1 + _helpMarker.length);
    } else if (comment.startsWith(_helpMarker)) {
      _help.text = comment.substring(_helpMarker.length);
    } else {
      _comment.text = comment;
    }
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Чек-ин текущей недели — тот же семидневный критерий, что и в
  /// контроллере напоминаний: точной границы недели API не отдаёт.
  static GoalCheckin? _currentWeekCheckin(Goal goal) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    GoalCheckin? found;
    for (final c in goal.checkins) {
      if (!c.weekStart.isAfter(cutoff)) continue;
      if (found == null || c.weekStart.isAfter(found.weekStart)) found = c;
    }
    return found;
  }

  /// Значение «неделю назад»: последний чек-ин, не считая текущей недели —
  /// сравнивать своё новое число с ним же самим бессмысленно.
  static GoalCheckin? _previousCheckin(Goal goal) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    GoalCheckin? best;
    for (final c in goal.checkins) {
      if (c.weekStart.isAfter(cutoff)) continue;
      if (best == null || c.weekStart.isAfter(best.weekStart)) best = c;
    }
    return best;
  }

  String? _composeComment() {
    final week = _comment.text.trim();
    final help = _needsHelp ? _help.text.trim() : '';

    if (help.isEmpty) return week.isEmpty ? null : week;
    if (week.isEmpty) return '$_helpMarker$help';
    return '$week\n$_helpMarker$help';
  }

  Future<void> _submit(Goal goal) async {
    if (_saving) return; // повторный tap во время запроса запрещён

    final raw = _value.text
        .trim()
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (raw.isEmpty || parsed == null) {
      setState(() => _error = 'Введите число — текущее значение метрики');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // Захватываем до await: после pop контекст экрана уже недействителен.
    final controller = context.read<GoalsController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await controller.checkin(
      goalId: goal.id,
      value: parsed,
      comment: _composeComment(),
      needsHelp: _needsHelp,
    );

    if (!mounted) return;

    if (error != null) {
      // Ошибка сервера: показываем текст, введённые данные не трогаем.
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('Check-in сохранён')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GoalsController>();
    final goal = _resolve(controller);

    if (goal == null) return _buildNoGoal(controller);

    // Цель могла приехать позже первого кадра (открытие по прямой ссылке).
    if (!_prefilled) _prefill(goal);

    return DSubScaffold(
      title: 'Check-in недели',
      subtitle: 'Зафиксируйте движение к цели',
      // Ошибка живёт рядом с кнопкой в закреплённой панели: в длинной
      // форме сообщение в конце скролла легко не заметить.
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: DColors.of(context).danger,
                ),
                const SizedBox(width: DSpace.xs),
                Expanded(
                  child: Text(
                    _error!,
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
            label: 'Отправить check-in',
            loading: _saving,
            onPressed: () => _submit(goal),
          ),
        ],
      ),
      children: [
        _GoalContextCard(goal: goal),
        const SizedBox(height: DSpace.section),

        const DSectionLabel('Текущая метрика'),
        const SizedBox(height: DSpace.sm),
        _metricField(goal),
        const SizedBox(height: DSpace.xs),
        Text(_previousValueLabel(goal), style: DText.of(context).caption),
        if (goal.hideAbsoluteValues) ...[
          const SizedBox(height: 2),
          // Приватность закрывает суммы от чужих глаз, но своё число
          // резидент вводит как обычно — это его собственные данные.
          Text(
            'Абсолютное значение видно только вам',
            style: DText.of(context).caption,
          ),
        ],
        const SizedBox(height: DSpace.section),

        TextField(
          key: const ValueKey('checkin-comment'),
          controller: _comment,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: DText.of(context).body,
          decoration: const InputDecoration(
            labelText: 'Что сделали за неделю?',
            hintText: 'Главное действие или результат недели',
          ),
        ),
        const SizedBox(height: DSpace.section),

        _NeedHelpToggle(
          value: _needsHelp,
          onChanged: (v) => setState(() => _needsHelp = v),
        ),
        if (_needsHelp) ...[
          const SizedBox(height: DSpace.md),
          TextField(
            key: const ValueKey('checkin-help'),
            controller: _help,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: DText.of(context).body,
            decoration: const InputDecoration(
              labelText: 'С чем нужна помощь?',
              hintText: 'Коротко: где именно застряли',
            ),
          ),
        ],
      ],
    );
  }

  /// Экран без цели: чек-ин привязан к цели, поэтому при её отсутствии
  /// показываем состояние контроллера, а не пустую форму.
  Widget _buildNoGoal(GoalsController controller) {
    final Widget body;

    if (controller.loading) {
      body = const DSkeletonCard(lines: 3);
    } else if (controller.error != null) {
      body = DErrorState(message: controller.error!, onRetry: controller.load);
    } else {
      // Тексты раздела 31; CTA «Поставить цель» живёт на Пульсе и Целях —
      // сюда без цели попадают только по устаревшей ссылке.
      body = const DEmptyState(
        title: 'Поставьте первую цель',
        message:
            'Сформулируйте измеримый результат и шаги, '
            'чтобы начать отслеживать движение.',
      );
    }

    return DSubScaffold(
      title: 'Check-in недели',
      subtitle: 'Зафиксируйте движение к цели',
      children: [body],
    );
  }

  // TODO(api): спецификация допускает slider «в зависимости от типа метрики»,
  // но API не отдаёт тип метрики (деньги/штуки/шкала) — пока всегда числовое
  // поле, как в прежнем sheet. Слайдер добавим, когда появится metric.type.
  Widget _metricField(Goal goal) {
    return TextField(
      key: const ValueKey('checkin-value'),
      controller: _value,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-\s]')),
      ],
      // Значение метрики — главное число экрана, показываем крупно акцентом.
      style: DText.of(
        context,
      ).kpi.copyWith(fontSize: 28, color: DColors.of(context).accent),
      decoration: InputDecoration(
        hintText: '0',
        suffixText: goal.metricUnit,
        suffixStyle: DText.of(
          context,
        ).cardTitle.copyWith(color: DColors.of(context).textSecondary),
        helperText: goal.metricName,
      ),
    );
  }

  String _previousValueLabel(Goal goal) {
    final previous = _previousCheckin(goal);
    if (previous != null) {
      return 'Неделю назад: ${Fmt.metric(previous.metricValue, goal.metricUnit)}';
    }
    return 'Старт: ${Fmt.metric(goal.metricFrom, goal.metricUnit)}';
  }
}

/// Блок 1 — контекст цели: название и текущий прогресс, компактно.
class _GoalContextCard extends StatelessWidget {
  const _GoalContextCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      padding: const EdgeInsets.all(DSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title, style: DText.of(context).cardTitle),
                const SizedBox(height: DSpace.xs),
                Text('Текущий прогресс', style: DText.of(context).caption),
              ],
            ),
          ),
          const SizedBox(width: DSpace.md),
          // Процент не раскрывает абсолютных сумм, поэтому виден всегда.
          Text(
            '${goal.progressPercent}%',
            style: DText.of(
              context,
            ).kpi.copyWith(color: DColors.of(context).accent),
          ),
        ],
      ),
    );
  }
}

/// Блок 4 — флаг «нужна помощь». Вся карточка кликабельна: одна из самых
/// важных механик клуба не должна требовать попадания в маленький Switch.
class _NeedHelpToggle extends StatelessWidget {
  const _NeedHelpToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Нужна помощь на мастермайнде',
      child: DBrandCard(
        padding: const EdgeInsets.fromLTRB(
          DSpace.lg,
          DSpace.md,
          DSpace.md,
          DSpace.md,
        ),
        background: value
            ? DColors.of(context).surface2
            : DColors.of(context).surface,
        borderColor: value
            ? DColors.of(context).accentBorder
            : DColors.of(context).cardBorder,
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Я застрял — хочу разобрать это на мастермайнде',
                    style: DText.of(context).body,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Вопрос попадёт в повестку ближайшей встречи',
                    style: DText.of(context).caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: DSpace.sm),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

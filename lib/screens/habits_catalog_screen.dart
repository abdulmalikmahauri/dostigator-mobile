import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/content_report.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/habit.dart';
import '../state/habits_controller.dart';
import '../widgets/d_amount_dialog.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';

/// Присоединиться к общей привычке со своей нормой. true — получилось.
Future<bool> joinHabit(BuildContext context, ListedHabit habit) async {
  final habits = context.read<HabitsController>();
  final messenger = ScaffoldMessenger.of(context);

  final choice = await showAmountDialog(
    context,
    title: habit.title,
    message: 'Норма автора — ${habit.norm}. Поставьте свою.',
    initial: habit.target,
    unit: habit.unit,
    confirmLabel: 'Присоединиться',
  );

  if (choice is! AmountEntered) return false;

  try {
    await habits.join(habit.id, choice.value);
    messenger.showSnackBar(
      SnackBar(content: Text('«${habit.title}» теперь в ваших привычках')),
    );
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Общие привычки клуба: чем живут другие резиденты.
class HabitsCatalogScreen extends StatefulWidget {
  const HabitsCatalogScreen({super.key});

  @override
  State<HabitsCatalogScreen> createState() => _HabitsCatalogScreenState();
}

class _HabitsCatalogScreenState extends State<HabitsCatalogScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<ListedHabit> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<HabitsController>().catalog(
        query: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _join(ListedHabit habit) async {
    if (await joinHabit(context, habit)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DSubScaffold(
      title: 'Общие привычки клуба',
      subtitle:
          'Присоединяйтесь со своей нормой: отметки у каждого свои, '
          'а рейтинг — общий.',
      onRefresh: _load,
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: 'Поиск по названию',
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: DColors.of(context).textSecondary,
            ),
          ),
        ),
        const SizedBox(height: DSpace.section),
        if (_loading)
          const DSkeletonCard(lines: 3)
        else if (_error != null && _items.isEmpty)
          DErrorState(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          const DEmptyState(
            title: 'Общих привычек пока нет',
            message:
                'Заведите свою и откройте её всему клубу — '
                'к ней смогут присоединиться.',
          )
        else
          for (final h in _items) ...[
            _CatalogCard(habit: h, onJoin: () => _join(h)),
            const SizedBox(height: DSpace.md),
          ],
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.habit, required this.onJoin});

  final ListedHabit habit;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final h = habit;

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(h.title, style: t.cardTitle)),
              if (!h.isOwner)
                PopupMenuButton<void>(
                  tooltip: 'Ещё',
                  icon: const Icon(Icons.more_horiz, size: 20),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => reportContent(
                        context,
                        type: ReportedContent.habit,
                        id: h.id,
                        title: h.title,
                      ),
                      child: const Text('Пожаловаться'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${h.norm} · ${h.daysLabel}', style: t.caption),
          const SizedBox(height: 2),
          Text(
            [
              'Ведут: ${h.participantsCount}',
              if (h.ownerName != null) 'завёл ${h.ownerName}',
            ].join(' · '),
            style: t.caption,
          ),
          const SizedBox(height: DSpace.md),
          if (h.isJoined)
            const DStatusChip('Вы ведёте', tone: DChipTone.green)
          else
            OutlinedButton(
              onPressed: onJoin,
              child: const Text('Присоединиться'),
            ),
        ],
      ),
    );
  }
}

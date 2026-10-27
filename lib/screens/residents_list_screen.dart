import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/directory.dart';
import '../state/residents_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_filter_chip.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'resident_detail_screen.dart';

/// Раздел каталога — «Бизнес-клуб» или «Экосистема». Свой контроллер
/// на экран: поиск в одном разделе не должен всплывать в другом.
class ResidentsListScreen extends StatelessWidget {
  const ResidentsListScreen({super.key, required this.tier});

  final ResidentsTier tier;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ResidentsController(ctx.read<ApiClient>(), tier)..load(),
      child: const ResidentsListView(),
    );
  }
}

/// Содержимое раздела. Вынесено отдельно, чтобы тесты подставляли
/// свой контроллер без сети.
class ResidentsListView extends StatefulWidget {
  const ResidentsListView({super.key});

  @override
  State<ResidentsListView> createState() => _ResidentsListViewState();
}

class _ResidentsListViewState extends State<ResidentsListView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<ResidentsController>().query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ResidentsController>();
    final hasData = c.residents.isNotEmpty;
    final isSearching = c.query.trim().isNotEmpty || c.niche != null;

    return DSubScaffold(
      title: c.tier.title,
      subtitle: hasData && !isSearching
          ? Fmt.plural(
              c.residents.length,
              'резидент',
              'резидента',
              'резидентов',
            )
          : null,
      onRefresh: () => c.load(silent: true),
      children: [
        _SearchField(controller: _searchController, onChanged: c.search),

        if (c.niches.isNotEmpty) ...[
          const SizedBox(height: DSpace.sm),
          _NicheFilter(
            niches: c.niches,
            selected: c.niche,
            onSelect: c.filterByNiche,
          ),
        ],

        const SizedBox(height: DSpace.section),

        if (c.loading && !hasData) ...[
          const DSkeletonCard(lines: 3),
          const SizedBox(height: DSpace.section),
          const DSkeletonCard(lines: 2),
        ] else if (c.error != null && !hasData)
          DErrorState(message: c.error!, onRetry: () => c.load())
        else ...[
          if (c.error != null) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: DColors.of(context).warning,
                ),
                const SizedBox(width: DSpace.xs),
                Expanded(
                  child: Text(
                    'Не удалось обновить результаты — показан прежний список',
                    style: DText.of(
                      context,
                    ).caption.copyWith(color: DColors.of(context).warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DSpace.md),
          ],

          if (!c.seesContacts) ...[
            // Не ошибка и не hidden state: участник экосистемы должен видеть,
            // что функция существует и открывается уровнем выше (раздел 28)
            DBrandCard(
              padding: const EdgeInsets.symmetric(
                horizontal: DSpace.md,
                vertical: DSpace.sm,
              ),
              background: DColors.of(context).surface2,
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: DColors.of(context).textSecondary,
                  ),
                  const SizedBox(width: DSpace.sm),
                  Expanded(
                    child: Text(
                      'Контакты резидентов открыты участникам бизнес-клуба',
                      style: DText.of(context).caption,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DSpace.sm),
          ],

          ResidentsSection(
            residents: c.residents,
            filterKey: '${c.query}|${c.niche ?? ''}',
            // В клубном разделе все клубные — метка там ничего не добавляет
            markClub: c.tier == ResidentsTier.ecosystem,
          ),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      // Debounce уже в контроллере — каждый символ не уходит в сеть
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Поиск по имени, компании, нише',
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: DColors.of(context).textSecondary,
        ),
      ),
    );
  }
}

class _NicheFilter extends StatelessWidget {
  const _NicheFilter({
    required this.niches,
    required this.selected,
    required this.onSelect,
  });

  final List<String> niches;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    // Высота 44 — чтобы вся полоса чипов была нормальной touch-целью
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          DFilterChip(
            label: 'Все ниши',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final n in niches)
            DFilterChip(
              label: n,
              selected: selected == n,
              // Повторный tap по выбранной нише снимает фильтр
              onTap: () => onSelect(selected == n ? null : n),
            ),
        ],
      ),
    );
  }
}

/// Список резидентов: первые 12 видны сразу, остальные — по нажатию.
/// Полсотни карточек подряд читаются как стена, а найти конкретного
/// человека быстрее поиском, чем прокруткой.
class ResidentsSection extends StatefulWidget {
  const ResidentsSection({
    super.key,
    required this.residents,
    required this.filterKey,
    this.markClub = false,
  });

  final List<DirectoryEntry> residents;

  /// Сменился — список снова сворачивается: иначе один раз раскрытые
  /// «все» превратили бы каждый следующий запрос в то самое полотно.
  final String filterKey;

  /// Отмечать членов клуба меткой (нужно в разделе «Экосистема»).
  final bool markClub;

  static const collapsedCount = 12;

  @override
  State<ResidentsSection> createState() => _ResidentsSectionState();
}

class _ResidentsSectionState extends State<ResidentsSection> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ResidentsSection old) {
    super.didUpdateWidget(old);
    if (old.filterKey != widget.filterKey) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final residents = widget.residents;
    final total = residents.length;
    final visible = _expanded || total <= ResidentsSection.collapsedCount
        ? total
        : ResidentsSection.collapsedCount;
    final hidden = total - visible;

    if (residents.isEmpty) {
      return const DEmptyState(
        title: 'Никого не нашлось',
        message: 'Попробуйте другой запрос или снимите фильтр по нише.',
      );
    }

    return DBrandCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.md,
        vertical: DSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < visible; i++) ...[
            _ResidentRow(entry: residents[i], markClub: widget.markClub),
            if (i < visible - 1) const Divider(),
          ],
          if (total > ResidentsSection.collapsedCount) ...[
            const Divider(),
            _ShowAllRow(
              expanded: _expanded,
              hidden: hidden,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Продолжение списка, а не отдельная кнопка: строка живёт в той же
/// карточке и подхватывает её ритм, поэтому раскрытие читается как
/// «список продолжается», а не как переход куда-то ещё.
class _ShowAllRow extends StatelessWidget {
  const _ShowAllRow({
    required this.expanded,
    required this.hidden,
    required this.onTap,
  });

  final bool expanded;
  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = DColors.of(context).accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DRadius.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DSpace.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expanded ? 'Свернуть список' : 'Показать всех — ещё $hidden',
              style: DText.of(
                context,
              ).body.copyWith(color: accent, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: DSpace.xs),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidentRow extends StatelessWidget {
  const _ResidentRow({required this.entry, required this.markClub});

  final DirectoryEntry entry;
  final bool markClub;

  @override
  Widget build(BuildContext context) {
    final Widget? trailing;
    if (entry.isMe) {
      trailing = const DStatusChip('Это вы');
    } else if (markClub && entry.isClub) {
      trailing = const DStatusChip('Бизнес-клуб', tone: DChipTone.greenOutline);
    } else {
      trailing = null;
    }

    return DListRow(
      title: entry.name,
      subtitle: entry.businessName ?? entry.niche,
      leading: DUserAvatar(name: entry.name, photoUrl: entry.avatarUrl),
      trailing: trailing,
      chevron: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResidentDetailScreen(entry: entry),
        ),
      ),
    );
  }
}

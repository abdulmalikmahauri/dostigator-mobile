import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/resident.dart';
import '../state/auth_controller.dart';
import '../state/directory_controller.dart';
import '../state/residents_controller.dart';
import '../widgets/d_app_scaffold.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_list_row.dart';
import 'card_screen.dart';
import 'residents_list_screen.dart';
import 'knowledge_screen.dart';

/// Вкладка «Клуб»: два раздела сообщества и карта резидента.
///
/// Списка людей здесь нет намеренно: полсотни карточек на входе
/// превращали вкладку в стену. Вместо этого — две двери с числом
/// за каждой и карта, в которой собраны привилегии.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DirectoryController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DirectoryController>();
    final resident = context.watch<AuthController>().resident;

    return DAppScaffold(
      title: 'Клуб',
      subtitle: 'Люди. Связи. Привилегии.',
      onRefresh: () => c.load(silent: true),
      children: [
        if (c.loading && !c.hasData) ...[
          const DSkeletonCard(lines: 2),
          const SizedBox(height: DSpace.md),
          const DSkeletonCard(lines: 2),
          const SizedBox(height: DSpace.section),
          const DSkeletonCard(lines: 3),
        ] else if (c.error != null && !c.hasData)
          DErrorState(message: c.error!, onRetry: () => c.load())
        else ...[
          const DSectionLabel('Резиденты'),
          const SizedBox(height: DSpace.sm),
          _TierCard(
            tier: ResidentsTier.club,
            count: c.stats.club,
            caption: 'Контакты, мастермайнды, закрытые встречи',
            icon: Icons.shield_outlined,
            emphasized: true,
          ),
          const SizedBox(height: DSpace.sm),
          _TierCard(
            tier: ResidentsTier.ecosystem,
            count: c.stats.residents,
            caption: 'Все резиденты сообщества',
            icon: Icons.people_outline,
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Карта резидента'),
          const SizedBox(height: DSpace.sm),
          _ResidentCardTile(resident: resident, offersCount: c.offersCount),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('База знаний'),
          const SizedBox(height: DSpace.sm),
          DBrandCard(
            padding: const EdgeInsets.symmetric(
              horizontal: DSpace.card,
              vertical: DSpace.xs,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const KnowledgeScreen()),
            ),
            child: DListRow(
              title: 'Курсы, лекции и мастер-классы',
              subtitle: 'Видео и тексты клуба',
              leading: Icon(
                Icons.school_outlined,
                size: 22,
                color: DColors.of(context).accent,
              ),
              chevron: true,
            ),
          ),
        ],
      ],
    );
  }
}

/// Вход в раздел. Клубная карточка выделена поверхностью и контуром:
/// это старший уровень, и он должен читаться как таковой без слов.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.count,
    required this.caption,
    required this.icon,
    this.emphasized = false,
  });

  final ResidentsTier tier;
  final int count;
  final String caption;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    return DBrandCard(
      background: emphasized ? c.surface2 : null,
      borderColor: emphasized ? c.accentBorder : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResidentsListScreen(tier: tier),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(DRadius.input),
            ),
            child: Icon(icon, size: 22, color: c.accent),
          ),
          const SizedBox(width: DSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.title, style: t.cardTitle),
                const SizedBox(height: 2),
                Text(caption, style: t.caption),
              ],
            ),
          ),
          const SizedBox(width: DSpace.sm),
          if (count > 0)
            Text(
              '$count',
              style: t.kpi.copyWith(
                color: emphasized ? c.accent : c.textPrimary,
              ),
            ),
          const SizedBox(width: DSpace.xs),
          Icon(Icons.chevron_right, size: 20, color: c.textTertiary),
        ],
      ),
    );
  }
}

/// Карта резидента на вкладке — уменьшенная версия самой карты: имя,
/// уровень, номер и сколько привилегий внутри. Нажатие открывает QR
/// и полный список привилегий.
class _ResidentCardTile extends StatelessWidget {
  const _ResidentCardTile({required this.resident, required this.offersCount});

  final Resident? resident;
  final int offersCount;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);
    final r = resident;

    return DBrandCard(
      background: c.surface2,
      radius: DRadius.cardLarge,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ResidentCardScreen()),
      ),
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
                    Text(r?.name ?? 'Резидент', style: t.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      r?.tierLabel ?? 'Резидент',
                      style: t.caption.copyWith(color: c.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.md),
              Image.asset(
                'assets/brand/logo_mark.png',
                width: 28,
                height: 28,
                color: c.accent,
                colorBlendMode: BlendMode.srcIn,
              ),
            ],
          ),
          const SizedBox(height: DSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  (r == null || r.cardNumber.isEmpty) ? '—' : r.cardNumber,
                  style: t.kpi.copyWith(fontSize: 16, letterSpacing: 0.4),
                ),
              ),
              Icon(Icons.qr_code_2, size: 18, color: c.textSecondary),
              const SizedBox(width: DSpace.xs),
              Text(
                offersCount == 0
                    ? 'Показать QR'
                    : Fmt.plural(
                        offersCount,
                        'привилегия',
                        'привилегии',
                        'привилегий',
                      ),
                style: t.caption,
              ),
              const SizedBox(width: DSpace.xs),
              Icon(Icons.chevron_right, size: 18, color: c.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}

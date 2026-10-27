import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event_proposal.dart';
import '../state/events_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'event_proposal_screen.dart';

/// Мои предложения мероприятий и что по ним решили организаторы.
class MyProposalsScreen extends StatefulWidget {
  const MyProposalsScreen({super.key});

  @override
  State<MyProposalsScreen> createState() => _MyProposalsScreenState();
}

class _MyProposalsScreenState extends State<MyProposalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EventsController>().loadProposals();
    });
  }

  Future<void> _propose() async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EventProposalScreen()),
    );

    if (sent == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Предложение отправлено организаторам')),
      );
    }
  }

  Future<void> _withdraw(EventProposal p) async {
    final events = context.read<EventsController>();
    final messenger = ScaffoldMessenger.of(context);

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отозвать предложение?'),
        content: Text(
          '«${p.title}» больше не увидят организаторы. '
          'Предложить заново можно в любой момент.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Оставить'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Отозвать'),
          ),
        ],
      ),
    );

    if (sure != true) return;

    final error = await events.withdraw(p.id);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();
    final list = c.proposals;

    return DSubScaffold(
      title: 'Мои предложения',
      onRefresh: c.loadProposals,
      children: [
        if (c.proposalsLoading && list.isEmpty) ...[
          const DSkeletonCard(lines: 2),
          const SizedBox(height: DSpace.md),
          const DSkeletonCard(lines: 2),
        ] else if (c.proposalsError != null && list.isEmpty)
          DErrorState(message: c.proposalsError!, onRetry: c.loadProposals)
        else if (list.isEmpty)
          DEmptyState(
            title: 'Вы пока ничего не предлагали',
            message:
                'Предложите встречу, семинар или поездку — организаторы '
                'посмотрят и опубликуют в афише.',
            actionLabel: 'Предложить мероприятие',
            onAction: _propose,
          )
        else ...[
          for (final p in list) ...[
            _ProposalCard(proposal: p, onWithdraw: () => _withdraw(p)),
            const SizedBox(height: DSpace.md),
          ],
          const SizedBox(height: DSpace.sm),
          OutlinedButton.icon(
            onPressed: _propose,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Предложить ещё'),
          ),
        ],
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal, required this.onWithdraw});

  final EventProposal proposal;
  final VoidCallback onWithdraw;

  static final _when = DateFormat('d MMMM y, HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final t = DText.of(context);
    final reason = p.rejectionReason?.trim();

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(p.title, style: t.cardTitle)),
              const SizedBox(width: DSpace.sm),
              _status(p),
            ],
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            [
              p.typeLabel,
              if (p.formatLabel.isNotEmpty) p.formatLabel,
            ].join(' · '),
            style: t.caption,
          ),
          const SizedBox(height: 2),
          Text(_when.format(p.startsAt), style: t.caption),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: DSpace.sm),
            Text('Причина: $reason', style: t.bodyMuted),
          ],
          if (p.canWithdraw) ...[
            const SizedBox(height: DSpace.xs),
            TextButton(
              onPressed: onWithdraw,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Отозвать'),
            ),
          ],
        ],
      ),
    );
  }

  DStatusChip _status(EventProposal p) => switch (p.status) {
    'pending' => DStatusChip(p.statusLabel, tone: DChipTone.yellow),
    'published' => DStatusChip(p.statusLabel, tone: DChipTone.green),
    'draft' => DStatusChip(p.statusLabel, tone: DChipTone.outline),
    _ => DStatusChip(p.statusLabel, tone: DChipTone.muted),
  };
}

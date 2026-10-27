import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/directory.dart';
import '../state/directory_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'resident_detail_screen.dart';

// TODO(api): у партнёра в API нет логотипа (logo) — блок с logo из раздела 22
// опущен, показываем только название и категорию.

/// Экран привилегии партнёра (раздел 22 спецификации).
class PartnerOfferDetailScreen extends StatefulWidget {
  const PartnerOfferDetailScreen({
    super.key,
    required this.partner,
    required this.offer,
  });

  final Partner partner;
  final PartnerOffer offer;

  @override
  State<PartnerOfferDetailScreen> createState() =>
      _PartnerOfferDetailScreenState();
}

class _PartnerOfferDetailScreenState extends State<PartnerOfferDetailScreen> {
  bool _saving = false;

  /// Привилегия отмечена в этой сессии — после этого показываем
  /// накопитель «заявлено/подтверждено» вместо повторного CTA.
  bool _redeemed = false;

  @override
  Widget build(BuildContext context) {
    final partner = widget.partner;
    final offer = widget.offer;
    // watch: после redeem контроллер обновляет savings, блок должен перерисоваться
    final savings = context.watch<DirectoryController>().savings;

    return DSubScaffold(
      title: 'Привилегия',
      children: [
        // Партнёр
        Text(partner.name, style: DText.of(context).h1),
        if (partner.category != null) ...[
          const SizedBox(height: DSpace.xs),
          Text(partner.category!, style: DText.of(context).bodyMuted),
        ],
        if (partner.resident != null) ...[
          const SizedBox(height: DSpace.sm),
          _ResidentLine(resident: partner.resident!, onOpen: _openResident),
        ],
        if (partner.address != null) ...[
          const SizedBox(height: DSpace.xs),
          Text(partner.address!, style: DText.of(context).caption),
        ],
        if (partner.website != null) ...[
          const SizedBox(height: DSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openWebsite(partner.website!),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
              ),
              child: Text(partner.website!),
            ),
          ),
        ],

        const SizedBox(height: DSpace.section),

        // Оффер: выгода — крупно, остальное спокойным текстом
        DBrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.benefit,
                style: DText.of(
                  context,
                ).ringValue.copyWith(color: DColors.of(context).accent),
              ),
              const SizedBox(height: DSpace.sm),
              Text(offer.title, style: DText.of(context).cardTitle),
              if (offer.conditions != null) ...[
                const SizedBox(height: DSpace.sm),
                Text(offer.conditions!, style: DText.of(context).bodyMuted),
              ],
              if (offer.validUntil != null) ...[
                const SizedBox(height: DSpace.sm),
                Text(
                  'Действует до ${Fmt.date(offer.validUntil!)}',
                  style: DText.of(context).caption,
                ),
              ],
              if (offer.minTierLabel != null) ...[
                const SizedBox(height: DSpace.sm),
                Text(
                  'Уровень доступа: ${offer.minTierLabel}',
                  style: DText.of(context).caption,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: DSpace.section),

        if (!offer.isAvailable)
          // Функция не скрывается, а помечается уровнем доступа (раздел 28)
          const Align(
            alignment: Alignment.centerLeft,
            child: DStatusChip(
              'Только для бизнес-клуба',
              tone: DChipTone.outline,
            ),
          )
        else if (!_redeemed)
          DPrimaryButton(
            label: 'Использовать привилегию',
            loading: _saving,
            onPressed: _redeem,
          ),

        if (_redeemed) ...[
          const DSectionLabel('Накопленная экономия'),
          const SizedBox(height: DSpace.sm),
          DBrandCard(
            child: Column(
              children: [
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
            ),
          ),
        ],
      ],
    );
  }

  /// К владельцу привилегии — в его карточку. Полной карточки у партнёра
  /// нет, только id: забираем её с сервера по нажатию.
  Future<void> _openResident(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final entry = await context.read<DirectoryController>().fetchEntry(id);

    if (!mounted) return;

    if (entry == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть карточку резидента')),
      );
      return;
    }

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ResidentDetailScreen(entry: entry),
      ),
    );
  }

  Future<void> _openWebsite(String url) async {
    // Сайты партнёров приходят и без схемы — добавляем https сами
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _redeem() async {
    if (_saving) return;

    // null — диалог закрыт без ответа, 0 — «Не знаю», >0 — сумма экономии
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => const _SavedAmountDialog(),
    );

    if (amount == null || !mounted) return;

    setState(() => _saving = true);

    final controller = context.read<DirectoryController>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.redeem(
      widget.offer.id,
      savedAmount: amount > 0 ? amount : null,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _redeemed = error == null;
    });

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Привилегия отмечена')),
    );
  }
}

/// Чья это привилегия: фото, имя и подпись «Резидент клуба». Нажатие
/// ведёт в карточку — связь между людьми здесь важнее скидки.
class _ResidentLine extends StatelessWidget {
  const _ResidentLine({required this.resident, required this.onOpen});

  final PartnerResident resident;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    return InkWell(
      onTap: () => onOpen(resident.id),
      borderRadius: BorderRadius.circular(DRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DSpace.xs),
        child: Row(
          children: [
            DUserAvatar(
              name: resident.name,
              photoUrl: resident.avatarUrl,
              size: 32,
            ),
            const SizedBox(width: DSpace.sm),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: t.body,
                  children: [
                    TextSpan(text: resident.name),
                    TextSpan(text: ' · резидент клуба', style: t.caption),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Диалог «Сколько удалось сэкономить?» — сумма нужна накопителю экономии,
/// чтобы к концу года было видно, окупается ли членство.
class _SavedAmountDialog extends StatefulWidget {
  const _SavedAmountDialog();

  @override
  State<_SavedAmountDialog> createState() => _SavedAmountDialogState();
}

class _SavedAmountDialogState extends State<_SavedAmountDialog> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сколько удалось сэкономить?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цифра приблизительная — она попадёт в накопитель экономии клуба.',
            style: DText.of(context).caption,
          ),
          const SizedBox(height: DSpace.md),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Сумма',
              suffixText: '₽',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text('Не знаю'),
        ),
        FilledButton(
          // Нечисловой ввод приравниваем к «не знаю»: привилегия всё равно
          // отмечается, просто без суммы
          onPressed: () => Navigator.of(
            context,
          ).pop(int.tryParse(_amountController.text.trim()) ?? 0),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text('Сохранить'),
        ),
      ],
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
    return Row(
      children: [
        Expanded(child: Text(label, style: DText.of(context).bodyMuted)),
        Text(
          Fmt.metric(value.toDouble(), '₽'),
          style: emphasized
              ? DText.of(
                  context,
                ).kpi.copyWith(color: DColors.of(context).accent)
              : DText.of(
                  context,
                ).body.copyWith(color: DColors.of(context).textSecondary),
        ),
      ],
    );
  }
}

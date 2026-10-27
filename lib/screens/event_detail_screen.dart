import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event.dart';
import '../state/events_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_qr_card.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'photo_gallery_screen.dart';

/// Детали события и билет: факты о встрече, фото, описание, партнёры,
/// регистрация и QR серверного билета.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final ClubEvent event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<EventPhoto>? _photos;
  bool _photosFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.event.photosCount > 0) _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (_photosFailed) setState(() => _photosFailed = false);

    try {
      final photos = await context.read<EventsController>().photos(
        widget.event.id,
      );
      if (mounted) setState(() => _photos = photos);
    } on ApiException {
      if (mounted) setState(() => _photosFailed = true);
    }
  }

  /// Потянули экран вниз — свежие места, отметки и фото.
  Future<void> _refresh(EventsController c, ClubEvent shown) async {
    await Future.wait([c.load(silent: true), if (shown.isPast) c.loadPast()]);

    final fresh = c.find(widget.event.id) ?? shown;
    if (mounted && fresh.photosCount > 0) await _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();
    // После записи/отмены контроллер перечитывает списки, а переданный
    // в конструктор объект остаётся старым — берём свежую копию по id
    final e = c.find(widget.event.id) ?? widget.event;
    final busy = c.busyEventId == e.id;
    final hasPhotos = e.photosCount > 0 || e.photosLink != null;

    return DSubScaffold(
      title: 'Событие',
      onRefresh: () => _refresh(c, e),
      bottom: _bottomCta(context, e, busy),
      children: [
        _Hero(event: e),

        if (hasPhotos) ...[
          const SizedBox(height: DSpace.section),
          const DSectionLabel('Фото'),
          const SizedBox(height: DSpace.sm),
          _PhotosBlock(
            event: e,
            photos: _photos,
            failed: _photosFailed,
            onRetry: _loadPhotos,
          ),
        ],

        // Описание — только фактический контент события, без маркетинга
        if (e.description != null && e.description!.trim().isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          const DSectionLabel('О событии'),
          const SizedBox(height: DSpace.sm),
          Text(e.description!.trim(), style: DText.of(context).body),
        ],

        if (e.speaker != null && e.speaker!.trim().isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          const DSectionLabel('Спикер'),
          const SizedBox(height: DSpace.sm),
          DBrandCard(
            padding: const EdgeInsets.all(DSpace.md),
            child: Row(
              children: [
                DUserAvatar(name: e.speaker!, size: 44),
                const SizedBox(width: DSpace.md),
                Expanded(
                  child: Text(e.speaker!, style: DText.of(context).cardTitle),
                ),
              ],
            ),
          ),
        ],

        if (e.partners.isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          const DSectionLabel('Партнёры'),
          const SizedBox(height: DSpace.sm),
          DRowsCard(
            children: [
              for (final p in e.partners)
                DListRow(
                  title: p.name,
                  subtitle: p.category,
                  leading: Icon(
                    Icons.handshake_outlined,
                    size: 20,
                    color: DColors.of(context).textTertiary,
                  ),
                ),
            ],
          ),
        ],

        ..._registration(context, e, busy),
      ],
    );
  }

  /// Прижатый к низу CTA показываем только пока запись возможна в принципе:
  /// активная «Записаться» или выключенная «Мест нет».
  Widget? _bottomCta(BuildContext context, ClubEvent e, bool busy) {
    if (e.canRegister) {
      return DPrimaryButton(
        label: 'Записаться',
        loading: busy,
        onPressed: () => _register(context, e.id),
      );
    }

    if (e.isAvailable && !e.isPast && e.isFull && !e.isRegistered) {
      // onPressed == null — кнопка выключена стилем темы
      return const DPrimaryButton(label: 'Мест нет');
    }

    return null;
  }

  List<Widget> _registration(BuildContext context, ClubEvent e, bool busy) {
    if (e.checkedIn) {
      return const [
        SizedBox(height: DSpace.section),
        Align(
          alignment: Alignment.centerLeft,
          child: DStatusChip('Отмечен на входе', tone: DChipTone.green),
        ),
      ];
    }

    // Прошло — билет и отмена записи больше ни к чему
    if (e.isPast) return const [];

    if (e.isRegistered) {
      return [
        const SizedBox(height: DSpace.section),
        const DSectionLabel('Билет'),
        const SizedBox(height: DSpace.sm),
        DBrandCard(
          background: DColors.of(context).surface2,
          radius: DRadius.cardLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Вы зарегистрированы', style: DText.of(context).cardTitle),
              // QR только из серверного ticket — локальные идентификаторы
              // сервер не узнает на входе
              if (e.ticket != null) ...[
                const SizedBox(height: DSpace.lg),
                Center(
                  child: DQrCard(data: e.ticket!, caption: 'Покажите на входе'),
                ),
                const SizedBox(height: DSpace.sm),
                // Код дублируем текстом: сканера на входе может не оказаться
                SelectableText(
                  e.ticket!,
                  textAlign: TextAlign.center,
                  style: DText.of(context).caption.copyWith(letterSpacing: 0.5),
                ),
              ],
              const SizedBox(height: DSpace.lg),
              OutlinedButton(
                onPressed: busy ? null : () => _cancel(context, e.id),
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: DColors.of(context).textSecondary,
                        ),
                      )
                    : const Text('Отменить запись'),
              ),
            ],
          ),
        ),
      ];
    }

    if (!e.isAvailable) {
      // Событие не скрываем, но честно показываем ограничение
      return [
        const SizedBox(height: DSpace.section),
        const Align(
          alignment: Alignment.centerLeft,
          child: DStatusChip(
            'Только для бизнес-клуба',
            tone: DChipTone.outline,
          ),
        ),
        if (e.unavailableReason != null) ...[
          const SizedBox(height: DSpace.sm),
          Text(e.unavailableReason!, style: DText.of(context).caption),
        ],
      ];
    }

    return const [];
  }

  Future<void> _register(BuildContext context, int id) async {
    final c = context.read<EventsController>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await c.register(id);

    if (error != null) {
      // Гонку за последние места решает сервер: на 422 «мест больше нет»
      // показываем сообщение и перечитываем событие, чтобы CTA обновился
      messenger.showSnackBar(SnackBar(content: Text(error)));
      await c.load(silent: true);
    }
  }

  Future<void> _cancel(BuildContext context, int id) async {
    final c = context.read<EventsController>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await c.cancel(id);

    if (error != null) {
      // После check-in сервер отвечает 422 — показываем его сообщение
      // и синхронизируемся: состояние на сервере уже другое
      messenger.showSnackBar(SnackBar(content: Text(error)));
      await c.load(silent: true);
    }
  }
}

/// Шапка события: тип, название и фактические реквизиты встречи.
class _Hero extends StatelessWidget {
  const _Hero({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final seats = _seats(e);
    final topic = e.topic?.trim();

    return DBrandCard(
      background: DColors.of(context).surface2,
      radius: DRadius.cardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic == null || topic.isEmpty
                ? e.typeLabel
                : '${e.typeLabel} · $topic',
            style: DText.of(context).caption,
          ),
          const SizedBox(height: DSpace.xs),
          Text(e.title, style: DText.of(context).h1),
          const SizedBox(height: DSpace.lg),
          _InfoRow(icon: Icons.event_outlined, text: Fmt.date(e.startsAt)),
          const SizedBox(height: DSpace.xs),
          _InfoRow(icon: Icons.schedule, text: _timeRange(e)),
          if (e.formatLabel != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(icon: _formatIcon(e.format), text: e.formatLabel!),
          ],
          if (e.place != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(icon: Icons.place_outlined, text: e.place!),
          ],
          if (e.address != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(icon: Icons.map_outlined, text: e.address!),
          ],
          if (e.minTierLabel != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(
              icon: Icons.lock_outline,
              text: 'Доступ: ${e.minTierLabel}',
            ),
          ],
          if (seats != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(
              icon: Icons.people_outline,
              text: seats,
              // Жёлтый — только предупреждение о заканчивающихся местах
              color: e.isRunningOut ? DColors.of(context).warning : null,
            ),
          ],
        ],
      ),
    );
  }

  IconData _formatIcon(String? format) => switch (format) {
    'online' => Icons.videocam_outlined,
    'hybrid' => Icons.devices_outlined,
    _ => Icons.groups_outlined,
  };

  String? _seats(ClubEvent e) => e.isPast ? null : e.seatsSummary;

  String _timeRange(ClubEvent e) {
    final f = DateFormat('HH:mm');
    final start = f.format(e.startsAt);
    return e.endsAt == null ? start : '$start–${f.format(e.endsAt!)}';
  }
}

/// Превью фото сеткой и ссылка на всю папку. Девять превью — больше
/// на экране телефона уже не разглядеть; остальные в просмотре.
class _PhotosBlock extends StatelessWidget {
  const _PhotosBlock({
    required this.event,
    required this.photos,
    required this.failed,
    required this.onRetry,
  });

  final ClubEvent event;
  final List<EventPhoto>? photos;
  final bool failed;
  final VoidCallback onRetry;

  static const _shown = 9;

  @override
  Widget build(BuildContext context) {
    final list = photos;
    final link = event.photosLink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed)
          DErrorState(message: 'Фото не загрузились', onRetry: onRetry)
        else if (event.photosCount > 0 && list == null)
          const _GridSkeleton()
        else if (list != null && list.isNotEmpty)
          _grid(context, list)
        else if (link != null)
          Text(
            'Фото скоро появятся здесь, а пока их можно открыть по ссылке.',
            style: DText.of(context).bodyMuted,
          ),
        if (link != null) ...[
          const SizedBox(height: DSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openLink(context, link),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Все фото на Яндекс Диске'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _grid(BuildContext context, List<EventPhoto> list) {
    final rest = list.length - _shown;
    final c = DColors.of(context);

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < list.length && i < _shown; i++)
          Semantics(
            button: true,
            label: 'Фото ${i + 1} из ${list.length}',
            onTap: () => _open(context, list, i),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _open(context, list, i),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      list[i].thumbUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: c.surface3),
                    ),
                    if (i == _shown - 1 && rest > 0)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Center(
                          child: Text(
                            '+$rest',
                            style: DText.of(
                              context,
                            ).h2.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context, List<EventPhoto> list, int index) {
    PhotoGalleryScreen.open(
      context,
      urls: [for (final p in list) p.url],
      initialIndex: index,
      title: event.title,
    );
  }

  Future<void> _openLink(BuildContext context, String link) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(link);
    var opened = false;

    // Ссылку задаёт организатор, но открываем только обычный https
    if (uri != null && uri.scheme == 'https') {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не получилось открыть ссылку')),
      );
    }
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          const Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: DSkeleton(height: double.infinity, radius: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? DColors.of(context).textTertiary),
        const SizedBox(width: DSpace.sm),
        Expanded(
          child: Text(
            text,
            style: color == null
                ? DText.of(context).bodyMuted
                : DText.of(context).body.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

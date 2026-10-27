import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_rows_card.dart';
import '../state/directory_controller.dart';
import '../models/habit.dart';
import '../core/content_report.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/directory.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_brand_glyphs.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'photo_view_screen.dart';

/// Карточка резидента в каталоге (раздел 21 спецификации).
///
/// Сверху — лицо, имя и дело, затем одна строка кнопок связи: человек
/// открывает карточку, чтобы узнать, кто это, и написать. Всё остальное
/// ниже, спокойным текстом.
///
/// Поля приходят уже отфильтрованными сервером по privacy и уровню членства:
/// null просто не показываем — это не ошибка и не «скрытое» состояние.
/// Raw номер телефона не выводится никогда: только deep-links мессенджеров.
class ResidentDetailScreen extends StatefulWidget {
  const ResidentDetailScreen({super.key, required this.entry});

  final DirectoryEntry entry;

  @override
  State<ResidentDetailScreen> createState() => _ResidentDetailScreenState();
}

class _ResidentDetailScreenState extends State<ResidentDetailScreen> {
  late DirectoryEntry entry = widget.entry;

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  /// В списке у резидента нет задач и привычек — карточку дозапрашиваем.
  /// Не вышло — показываем то, что уже есть.
  Future<void> _loadFull() async {
    final full = await context.read<DirectoryController>().fetchEntry(
      widget.entry.id,
    );
    if (full != null && mounted) setState(() => entry = full);
  }

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);

    // Строка «компания · город» — второстепенные атрибуты одним взглядом
    final businessLine = [
      if (entry.businessName != null) entry.businessName!,
      if (entry.city != null) entry.city!,
    ].join(' · ');

    return DSubScaffold(
      title: 'Резидент',
      children: [
        Center(
          child: Column(
            children: [
              _Portrait(entry: entry),
              const SizedBox(height: DSpace.md),
              Text(entry.name, style: t.h1, textAlign: TextAlign.center),
              if (businessLine.isNotEmpty) ...[
                const SizedBox(height: DSpace.xs),
                Text(
                  businessLine,
                  style: t.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
              if (entry.niche != null || entry.isClub || entry.isMe) ...[
                const SizedBox(height: DSpace.sm),
                Wrap(
                  spacing: DSpace.xs,
                  runSpacing: DSpace.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    if (entry.isClub)
                      const DStatusChip('Бизнес-клуб', tone: DChipTone.green),
                    if (entry.niche != null)
                      DStatusChip(entry.niche!, tone: DChipTone.greenOutline),
                    if (entry.isMe) const DStatusChip('Это вы'),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: DSpace.section),
        _ContactsRow(entry: entry),

        if (entry.description != null)
          _TextSection(label: 'О бизнесе', text: entry.description!),
        if (entry.canHelp != null)
          _TextSection(label: 'Чем могу быть полезен', text: entry.canHelp!),
        if (entry.lookingFor != null)
          _TextSection(label: 'Что ищет', text: entry.lookingFor!),

        if (entry.tasks.isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          _TasksBlock(entry: entry),
        ],
        if (entry.habits.isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          _HabitsBlock(entry: entry),
        ],

        if (entry.privileges.isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          _PrivilegesBlock(privileges: entry.privileges),
        ],
      ],
    );
  }
}

/// Пожаловаться на чужое — флажок справа в строке. У себя его нет.
Widget? _reportButton(
  BuildContext context,
  DirectoryEntry entry,
  ReportedContent type,
  int id,
  String title,
) {
  if (entry.isMe) return null;

  return IconButton(
    tooltip: 'Пожаловаться: $title',
    onPressed: () => reportContent(context, type: type, id: id, title: title),
    icon: Icon(
      Icons.flag_outlined,
      size: 18,
      color: DColors.of(context).textTertiary,
    ),
  );
}

/// Задачи «видят все»: над чем резидент работает сейчас.
class _TasksBlock extends StatelessWidget {
  const _TasksBlock({required this.entry});

  final DirectoryEntry entry;

  static final _due = DateFormat('d MMMM', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DSectionLabel('Задачи'),
        const SizedBox(height: DSpace.sm),
        DRowsCard(
          children: [
            for (final task in entry.tasks)
              DListRow(
                title: task.title,
                subtitle: task.dueOn == null
                    ? null
                    : 'до ${_due.format(task.dueOn!)}',
                trailing: _reportButton(
                  context,
                  entry,
                  ReportedContent.task,
                  task.id,
                  task.title,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Общие привычки резидента и как он их держит.
class _HabitsBlock extends StatelessWidget {
  const _HabitsBlock({required this.entry});

  final DirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DSectionLabel('Привычки'),
        const SizedBox(height: DSpace.sm),
        DRowsCard(
          children: [
            for (final habit in entry.habits)
              DListRow(
                title: habit.title,
                subtitle: Habit.unitText(habit.target, habit.unit),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (habit.percent != null)
                      Text(
                        '${habit.percent}%',
                        style: t.kpi.copyWith(fontSize: 17),
                      ),
                    ?_reportButton(
                      context,
                      entry,
                      ReportedContent.habit,
                      habit.id,
                      habit.title,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Фото резидента. Если оно есть, по нажатию открывается крупно —
/// в кружке 96 точек лица толком не рассмотреть.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.entry});

  final DirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final avatar = DUserAvatar(
      name: entry.name,
      photoUrl: entry.avatarUrl,
      size: 96,
    );
    final url = entry.avatarUrl;

    if (url == null) return avatar;

    return Semantics(
      button: true,
      label: 'Открыть фото',
      child: InkWell(
        onTap: () => PhotoViewScreen.open(context, url: url, name: entry.name),
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSectionLabel(label),
          const SizedBox(height: DSpace.xs),
          Text(text, style: DText.of(context).body),
        ],
      ),
    );
  }
}

/// Способы связи одной строкой. Мессенджеры открыты только клубу,
/// Instagram — публичная витрина, он виден всем, кому резидент его показал.
class _ContactsRow extends StatelessWidget {
  const _ContactsRow({required this.entry});

  final DirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    if (entry.isMe) {
      // Себе писать незачем — блок контактов не показываем вовсе
      return const SizedBox.shrink();
    }

    final instagram = entry.instagramUrl;
    final whatsapp = entry.canContact ? entry.whatsappUrl : null;
    final telegram = entry.canContact ? entry.telegramUrl : null;

    final tiles = <Widget>[
      if (whatsapp != null)
        _ContactTile(
          label: 'WhatsApp',
          icon: Icon(Icons.chat_bubble_outline, size: 22, color: c.accent),
          onTap: () => _open(context, whatsapp, 'WhatsApp'),
        ),
      if (telegram != null)
        _ContactTile(
          label: 'Telegram',
          icon: Icon(Icons.send_outlined, size: 22, color: c.accent),
          onTap: () => _open(context, telegram, 'Telegram'),
        ),
      if (instagram != null)
        _ContactTile(
          label: 'Instagram',
          icon: DInstagramGlyph(size: 22, color: c.accent),
          onTap: () => _open(context, instagram, 'Instagram'),
        ),
    ];

    final String? note;
    if (!entry.canContact) {
      // Спокойный текст, не ошибка: участник экосистемы должен понимать,
      // что контакты существуют и открываются членством в клубе (раздел 28)
      note = 'Контакты доступны участникам бизнес-клуба';
    } else if (whatsapp == null && telegram == null) {
      note = 'Резидент не указал способы связи';
    } else {
      note = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tiles.isNotEmpty)
          Row(
            children: [
              for (final (i, tile) in tiles.indexed) ...[
                if (i > 0) const SizedBox(width: DSpace.sm),
                Expanded(child: tile),
              ],
            ],
          ),
        if (note != null) ...[
          if (tiles.isNotEmpty) const SizedBox(height: DSpace.sm),
          Text(note, style: t.bodyMuted),
        ],
      ],
    );
  }

  /// Молчащая кнопка неотличима от сломанной: если мессенджер
  /// не установлен или ссылка битая — говорим об этом.
  Future<void> _open(BuildContext context, String url, String appName) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);

    var opened = false;
    if (uri != null) {
      try {
        // Ссылка должна открыть само приложение, а не webview
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Exception {
        opened = false;
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось открыть $appName')),
      );
    }
  }
}

/// Кнопка связи: значок и подпись в одной карточке. Подпись обязательна —
/// значки мессенджеров без слов различают не все.
class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Открыть $label',
      child: DBrandCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          vertical: DSpace.md,
          horizontal: DSpace.sm,
        ),
        child: Column(
          children: [
            icon,
            const SizedBox(height: DSpace.xs),
            Text(
              label,
              style: DText.of(context).caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Что бизнес этого резидента даёт членам клуба. Чтобы воспользоваться —
/// карта резидента: там та же привилегия с кнопкой «Использовать».
class _PrivilegesBlock extends StatelessWidget {
  const _PrivilegesBlock({required this.privileges});

  final List<ResidentPrivilege> privileges;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DSectionLabel('Привилегия для резидентов'),
        const SizedBox(height: DSpace.sm),
        DBrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, p) in privileges.indexed) ...[
                if (i > 0) ...[
                  const SizedBox(height: DSpace.sm),
                  const Divider(),
                  const SizedBox(height: DSpace.sm),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: t.body),
                          if (p.conditions != null) ...[
                            const SizedBox(height: 2),
                            Text(p.conditions!, style: t.caption),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: DSpace.sm),
                    DStatusChip(
                      p.benefit,
                      tone: p.isAvailable ? DChipTone.green : DChipTone.outline,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: DSpace.md),
              Text(
                'Покажите карту резидента, чтобы воспользоваться.',
                style: t.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

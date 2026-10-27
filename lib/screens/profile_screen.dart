import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/formatting.dart';
import '../core/push/push_service.dart';
import '../core/reminders.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/resident.dart';
import '../state/auth_controller.dart';
import '../state/goals_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_avatar_cropper.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_push_status.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'card_screen.dart';
import 'photo_view_screen.dart';
import 'profile_edit_screen.dart';

/// Профиль резидента (раздел 24 спецификации). Открывается с аватара
/// в header. Данные — из AuthController: отдельного запроса у экрана нет,
/// pull-to-refresh дёргает /me через refreshResident.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Версию держим строкой на экране, а не в pubspec-парсинге:
  /// это диагностическая подпись для разбора обращений, ей важно
  /// совпадать с тем, что реально собрано и выложено. За совпадением
  /// с pubspec.yaml следит тест.
  static const appVersion = '0.12.0';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final resident = auth.resident;

    return DSubScaffold(
      title: 'Профиль',
      onRefresh: auth.refreshResident,
      children: [
        if (resident == null && auth.stage == AuthStage.loading) ...[
          // Сессия ещё восстанавливается — скелет вместо пустого экрана
          const DSkeletonCard(lines: 3),
          const SizedBox(height: DSpace.section),
          const DSkeletonCard(),
        ] else if (resident == null)
          DErrorState(
            message: 'Не удалось загрузить профиль',
            onRetry: auth.refreshResident,
          )
        else ...[
          _IdentityCard(resident: resident),

          const SizedBox(height: DSpace.section),
          _BusinessCard(resident: resident),

          const SizedBox(height: DSpace.section),
          _PrivacyCard(profile: resident.profile),

          const SizedBox(height: DSpace.section),
          _CardLink(onTap: () => _openResidentCard(context)),

          const SizedBox(height: DSpace.section),
          // В браузере уведомления присылает сервер, в приложении
          // на телефоне их ставит само устройство — блоки разные
          if (context.read<PushService?>() != null)
            const DBrandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DSectionLabel('Уведомления'),
                  SizedBox(height: DSpace.md),
                  DPushStatus(),
                ],
              ),
            )
          else
            const _RemindersCard(),

          const SizedBox(height: DSpace.section),
          const _AccountCard(),
        ],
      ],
    );
  }

  void _openResidentCard(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ResidentCardScreen()));
  }
}

// ---------------------------------------------------------------------------
// Блок 1. Identity: кто это и в каком статусе он в клубе.
// ---------------------------------------------------------------------------

/// Своё фото: нажатие предлагает посмотреть его крупно, выбрать другое
/// или удалить. Выбранный снимок сначала подгоняют под круглую рамку.
/// Камеру не предлагаем — портрет для каталога обычно уже есть в телефоне,
/// а лишнее разрешение на камеру отпугивает на этапе проверки сторов.
class _AvatarButton extends StatefulWidget {
  const _AvatarButton({required this.resident});

  final Resident resident;

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final r = widget.resident;

    return Semantics(
      button: true,
      label: 'Фото профиля',
      child: InkWell(
        onTap: _busy ? null : _choose,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DUserAvatar(name: r.name, photoUrl: r.avatarUrl, size: 64),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: _busy
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.brandBlack,
                        ),
                      )
                    : Icon(
                        Icons.photo_camera_outlined,
                        size: 13,
                        color: c.brandBlack,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose() async {
    final photoUrl = widget.resident.avatarUrl;
    final hasPhoto = photoUrl != null;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: DSpace.sm),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Посмотреть фото'),
                onTap: () => Navigator.of(sheetContext).pop(_AvatarAction.view),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasPhoto ? 'Выбрать другое' : 'Выбрать из галереи'),
              onTap: () => Navigator.of(sheetContext).pop(_AvatarAction.pick),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: DColors.of(sheetContext).danger,
                ),
                title: const Text('Удалить фото'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AvatarAction.remove),
              ),
            const SizedBox(height: DSpace.sm),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _AvatarAction.view:
        if (photoUrl != null) {
          await PhotoViewScreen.open(
            context,
            url: photoUrl,
            name: widget.resident.name,
          );
        }
      case _AvatarAction.pick:
        await _pickAndUpload();
      case _AvatarAction.remove:
        await _remove();
    }
  }

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiClient>();
    final auth = context.read<AuthController>();

    final XFile? file;
    try {
      // Ужимаем ещё на телефоне: исходник с камеры в несколько мегабайт
      // по мобильной сети не нужен. Запас по размеру оставлен под
      // увеличение при обрезке — иначе лицо крупным планом выйдет мыльным
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
    } on PlatformException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть галерею')),
      );
      return;
    }

    if (file == null) return;

    final original = await file.readAsBytes();

    if (!mounted) return;

    // Подгонка под круглую рамку: человек сам решает, что попадёт в круг
    final cropped = await DAvatarCropper.open(context, original);

    if (cropped == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await api.upload(
        '/me/avatar',
        field: 'avatar',
        bytes: cropped,
        filename: 'avatar.png',
      );
      await auth.refreshResident();
      messenger.showSnackBar(const SnackBar(content: Text('Фото обновлено')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiClient>();
    final auth = context.read<AuthController>();

    setState(() => _busy = true);
    try {
      await api.delete('/me/avatar');
      await auth.refreshResident();
      messenger.showSnackBar(const SnackBar(content: Text('Фото удалено')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

enum _AvatarAction { view, pick, remove }

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.resident});

  final Resident resident;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AvatarButton(resident: resident),
              const SizedBox(width: DSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resident.name, style: DText.of(context).h2),
                    const SizedBox(height: 4),
                    // Свой телефон показывать можно: запрет на raw phone
                    // касается чужих контактов в каталоге
                    Text(
                      resident.phonePretty ?? resident.phone,
                      style: DText.of(context).bodyMuted,
                    ),
                    if (resident.city != null && resident.city!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(resident.city!, style: DText.of(context).caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DSpace.lg),
          const DSectionLabel('Членство'),
          const SizedBox(height: DSpace.sm),
          if (resident.memberships.isEmpty)
            // Уровень известен хотя бы из tier_label — показываем его,
            // даже если список членств бэкенд не прислал
            DStatusChip(
              resident.tierLabel ?? 'Резидент',
              tone: DChipTone.greenOutline,
            )
          else
            for (final m in resident.memberships) _MembershipRow(membership: m),
        ],
      ),
    );
  }
}

class _MembershipRow extends StatelessWidget {
  const _MembershipRow({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    // Просроченный взнос — единственный повод для жёлтого в этом блоке.
    // Говорим о нём прямо: жёлтое «Действует» при долге только путало
    final chipLabel = membership.isOverdue
        ? 'Взнос не оплачен'
        : membership.statusLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: DSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  membership.tierLabel,
                  style: DText.of(context).body,
                ),
              ),
              if (chipLabel.isNotEmpty)
                DStatusChip(
                  chipLabel,
                  tone: membership.isOverdue
                      ? DChipTone.yellow
                      : DChipTone.green,
                ),
            ],
          ),
          if (membership.paidUntil != null) ...[
            const SizedBox(height: 4),
            Text(
              'Оплачен до ${Fmt.date(membership.paidUntil!)}',
              style: DText.of(context).caption,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Блок 2. Бизнес-профиль и контакты. Резидент правит их сам.
// ---------------------------------------------------------------------------

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.resident});

  final Resident resident;

  @override
  Widget build(BuildContext context) {
    final profile = resident.profile;

    final fields = <(String, String?)>[
      ('Компания', profile?.businessName),
      ('Ниша', profile?.niche),
      ('О бизнесе', profile?.description),
      ('Чем могу быть полезен', profile?.canHelp),
      ('Что ищу', profile?.lookingFor),
      ('Сайт', profile?.website),
      ('Instagram', profile?.instagram),
      ('Telegram', resident.telegram),
      ('WhatsApp', resident.whatsapp),
    ].where((f) => f.$2 != null && f.$2!.isNotEmpty).toList();

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Бизнес-профиль'),
          const SizedBox(height: DSpace.md),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: DSpace.md),
              child: Text(
                'Бизнес-профиль пока не заполнен. Расскажите о своём деле — '
                'так вас быстрее найдут в клубе.',
                style: DText.of(context).bodyMuted,
              ),
            )
          else
            for (final (label, value) in fields) _Field(label, value),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileEditScreen(),
              ),
            ),
            child: Text(
              fields.isEmpty ? 'Заполнить профиль' : 'Изменить данные',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Блок 3. Приватность. Резидент сам решает, что из профиля видят другие.
// Каждый переключатель — отдельное поле на сервере; только на экране
// флагов не бывает.
// ---------------------------------------------------------------------------

/// Переключатели видимости: ключ поля на сервере, подпись, пояснение.
const _visibilityRows = <(String, String, String?)>[
  ('contacts', 'Кнопки связи', 'WhatsApp и Telegram в вашей карточке'),
  ('description', 'О бизнесе', null),
  ('can_help', 'Чем могу быть полезен', null),
  ('looking_for', 'Что ищу', null),
  ('employees_count', 'Число сотрудников', null),
  ('website', 'Сайт', null),
  ('instagram', 'Instagram', null),
];

class _PrivacyCard extends StatefulWidget {
  const _PrivacyCard({required this.profile});

  /// null — профиль ещё не подгружен: что видно другим, пока неизвестно.
  final ResidentProfile? profile;

  @override
  State<_PrivacyCard> createState() => _PrivacyCardState();
}

class _PrivacyCardState extends State<_PrivacyCard> {
  /// Поле, по которому сейчас идёт запрос. Пока он в полёте, остальные
  /// переключатели заперты — иначе быстрые нажатия перепишут друг друга.
  String? _saving;

  Future<void> _toggle(String field, bool value) async {
    setState(() => _saving = field);

    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AuthController>().updateProfile({
      'visibility': {field: value},
    });

    if (!mounted) return;

    setState(() => _saving = null);

    // При ошибке переключатель сам вернётся на место: он показывает
    // то, что ответил сервер, а не то, что нажали
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final t = DText.of(context);

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Приватность'),
          const SizedBox(height: DSpace.sm),
          Text(
            'Что из вашего профиля видят другие резиденты. '
            'Имя, фото, город, компания и ниша видны всегда.',
            style: t.bodyMuted,
          ),
          const SizedBox(height: DSpace.sm),
          for (final (field, label, hint) in _visibilityRows)
            Padding(
              // Высота строки не меньше 44 — вместе с переключателем
              padding: const EdgeInsets.symmetric(vertical: DSpace.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: t.body),
                        if (hint != null) ...[
                          const SizedBox(height: 2),
                          Text(hint, style: t.caption),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: DSpace.sm),
                  Semantics(
                    label: 'Показывать другим: $label',
                    child: Switch(
                      key: Key('visibility-$field'),
                      value: profile?.shows(field) ?? false,
                      onChanged: profile == null || _saving != null
                          ? null
                          : (value) => _toggle(field, value),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Блок 4. Карта резидента.
// ---------------------------------------------------------------------------

class _CardLink extends StatelessWidget {
  const _CardLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.card,
        vertical: DSpace.sm,
      ),
      onTap: onTap,
      child: DListRow(
        title: 'Карта резидента',
        subtitle: 'QR для входа на события и скидок партнёров',
        leading: Icon(
          Icons.qr_code_2,
          size: 24,
          color: DColors.of(context).accent,
        ),
        chevron: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Блок 5. Напоминания. Состояние нужно на экране, потому что молчащее
// уведомление неотличимо от отключённого: резидент должен видеть,
// работает оно или нет.
// ---------------------------------------------------------------------------

class _RemindersCard extends StatefulWidget {
  const _RemindersCard();

  @override
  State<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<_RemindersCard> {
  bool? _granted;
  int _pending = 0;
  bool _requesting = false;

  /// Канал уведомлений недоступен (урезанная прошивка) — честно говорим,
  /// что проверить не смогли, вместо вечного «Проверяем…».
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final granted = await Reminders.isGranted();
      final pending = await Reminders.pending();

      if (!mounted) return;

      setState(() {
        _granted = granted;
        _pending = pending.length;
        _unavailable = false;
      });
    } on MissingPluginException {
      if (mounted) setState(() => _unavailable = true);
    } on PlatformException {
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Future<void> _enable() async {
    setState(() => _requesting = true);

    try {
      await Reminders.requestPermission();

      if (!mounted) return;

      // Разрешение получено — сразу ставим расписание под текущую цель
      await context.read<GoalsController>().load(silent: true);
      await _refresh();
    } on PlatformException {
      if (mounted) setState(() => _unavailable = true);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Напоминания'),
          const SizedBox(height: DSpace.md),

          if (_unavailable)
            Text(
              'Не удалось проверить состояние уведомлений на этом устройстве.',
              style: DText.of(context).bodyMuted,
            )
          else if (granted == null)
            const DSkeleton(height: 15, width: 200)
          else if (!granted) ...[
            Text(
              'Уведомления отключены. Без них никто не напомнит про '
              'еженедельный чек-ин — придётся помнить самому.',
              style: DText.of(context).bodyMuted,
            ),
            const SizedBox(height: DSpace.md),
            DPrimaryButton(
              label: 'Разрешить напоминания',
              loading: _requesting,
              onPressed: _enable,
            ),
          ] else
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: DColors.of(context).accent,
                  size: 18,
                ),
                const SizedBox(width: DSpace.sm),
                Expanded(
                  child: Text(
                    _pending > 0
                        ? 'Напомним в пятницу утром и в воскресенье вечером'
                        : 'Чек-ин за эту неделю сделан — напоминаний не будет',
                    style: DText.of(context).body,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Блок 6. Аккаунт: пароль, выход, версия и сервер.
// ---------------------------------------------------------------------------

class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  /// Выход уже начат — прячем tap, чтобы logout не улетел дважды.
  bool _signingOut = false;

  /// Когда подан открытый запрос на удаление; null — запроса нет.
  DateTime? _deletionRequestedAt;

  /// Запрос на удаление или его отмена в полёте — второй tap не нужен.
  bool _deletionBusy = false;

  @override
  void initState() {
    super.initState();
    _loadDeletionRequest();
  }

  Future<void> _loadDeletionRequest() async {
    try {
      final res = await context.read<ApiClient>().get('/me/deletion-request');
      if (!mounted) return;
      setState(() => _deletionRequestedAt = _requestedAt(res));
    } on ApiException {
      // Состояние не загрузилось — пункт удаления остаётся доступным:
      // повторную подачу сервер сведёт к уже открытому запросу
    }
  }

  static DateTime? _requestedAt(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;

    return DateTime.tryParse(data['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Аккаунт'),
          const SizedBox(height: DSpace.xs),
          DListRow(
            title: 'Сменить пароль',
            leading: Icon(
              Icons.key_outlined,
              size: 20,
              color: DColors.of(context).textSecondary,
            ),
            chevron: true,
            onTap: () => _changePassword(context),
          ),
          const Divider(),
          DListRow(
            title: 'Выйти',
            leading: Icon(
              Icons.logout,
              size: 20,
              color: DColors.of(context).textSecondary,
            ),
            onTap: _signingOut ? null : () => _confirmSignOut(context),
          ),
          const Divider(),
          if (_deletionRequestedAt == null)
            DListRow(
              title: 'Удалить аккаунт',
              leading: Icon(
                Icons.delete_outline,
                size: 20,
                color: DColors.of(context).danger,
              ),
              onTap: _deletionBusy ? null : () => _requestDeletion(context),
            )
          else ...[
            DListRow(
              title: 'Запрос на удаление отправлен',
              subtitle:
                  '${Fmt.date(_deletionRequestedAt!)} · организатор закроет '
                  'членство и удалит данные',
              leading: Icon(
                Icons.hourglass_top_outlined,
                size: 20,
                color: DColors.of(context).warning,
              ),
            ),
            const Divider(),
            DListRow(
              title: 'Отменить запрос',
              leading: Icon(
                Icons.undo,
                size: 20,
                color: DColors.of(context).textSecondary,
              ),
              onTap: _deletionBusy ? null : () => _cancelDeletion(context),
            ),
          ],
          const Divider(),
          const SizedBox(height: DSpace.md),
          const _Field('Версия', ProfileScreen.appVersion),
          // Адрес сервера на виду: при разборе проблемы это первое,
          // что нужно знать, и первое, что забывают спросить.
          const _Field('Сервер', ApiConfig.baseUrl, last: true),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (changed == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Пароль изменён')));
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из приложения?'),
        content: const Text('Чтобы вернуться, понадобятся логин и пароль.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _signingOut = true);
    await context.read<AuthController>().signOut();
    // Экран уберёт корневой навигатор по смене stage; состояние
    // не возвращаем — виджета к этому моменту может уже не быть
  }

  Future<void> _requestDeletion(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiClient>();

    // null — человек передумал; пустая строка — подтвердил без причины
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DeletionDialog(),
    );
    if (reason == null || !mounted) return;

    setState(() => _deletionBusy = true);
    try {
      final res = await api.post('/me/deletion-request', {
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
      if (!mounted) return;
      setState(() => _deletionRequestedAt = _requestedAt(res));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deletionBusy = false);
    }
  }

  Future<void> _cancelDeletion(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiClient>();

    setState(() => _deletionBusy = true);
    try {
      await api.delete('/me/deletion-request');
      if (!mounted) return;
      setState(() => _deletionRequestedAt = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Запрос на удаление отменён')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deletionBusy = false);
    }
  }
}

/// Подтверждение удаления. Последствия объясняем до нажатия: удаление
/// идёт через организатора, а не мгновенно, и человек должен знать,
/// что именно сотрётся и что запрос ещё можно отменить.
class _DeletionDialog extends StatefulWidget {
  const _DeletionDialog();

  @override
  State<_DeletionDialog> createState() => _DeletionDialogState();
}

class _DeletionDialogState extends State<_DeletionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить аккаунт?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Запрос уйдёт организатору клуба. Он закроет членство и удалит '
              'ваши данные: имя, контакты, фото и профиль бизнеса. '
              'Восстановить их будет нельзя.',
            ),
            const SizedBox(height: DSpace.sm),
            Text(
              'Взносы и участие во встречах останутся в отчётности клуба, '
              'но без вашего имени. Пока запрос не обработан, его можно '
              'отменить здесь же.',
              style: DText.of(context).caption,
            ),
            const SizedBox(height: DSpace.md),
            TextField(
              controller: _reason,
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Причина — необязательно',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          style: TextButton.styleFrom(
            foregroundColor: DColors.of(context).danger,
          ),
          child: const Text('Отправить запрос'),
        ),
      ],
    );
  }
}

/// Смена пароля. Запрос выполняется прямо из диалога: пока он в полёте,
/// кнопка в loading и повторный tap невозможен, ошибка видна на месте.
/// Сервер при успехе разлогинивает прочие устройства, поэтому предупреждаем —
/// иначе человек решит, что что-то сломалось.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _minLength = 8;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _current.text.isNotEmpty && _next.text.length >= _minLength;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await context.read<AuthController>().changePassword(
      _current.text,
      _next.text,
    );

    if (!mounted) return;

    if (error == null) {
      // Пароль сменён — пусть телефон обновит сохранённую запись
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Смена пароля'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Одна группа: телефон понимает, что старый пароль меняют
          // на новый, и предлагает обновить сохранённую запись
          AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _current,
                  obscureText: true,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Текущий пароль',
                  ),
                ),
                const SizedBox(height: DSpace.md),
                TextField(
                  controller: _next,
                  obscureText: true,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    helperText: 'Не короче 8 символов',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DSpace.md),
          Text(
            'Другие устройства придётся войти заново.',
            style: DText.of(context).caption,
          ),
          if (_error != null) ...[
            const SizedBox(height: DSpace.sm),
            // Красный только здесь: неуспешный submit — это ошибка
            Text(
              _error!,
              style: DText.of(
                context,
              ).caption.copyWith(color: DColors.of(context).danger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy || !_canSubmit ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: DColors.of(context).brandBlack,
                  ),
                )
              : const Text('Сменить'),
        ),
      ],
    );
  }
}

/// Пара «подпись — значение». Пустые значения не рисуем вовсе:
/// прочерки создают ощущение сломанного экрана.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.last = false});

  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : DSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DText.of(context).caption),
          const SizedBox(height: 3),
          Text(value!, style: DText.of(context).body),
        ],
      ),
    );
  }
}

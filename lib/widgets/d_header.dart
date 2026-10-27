import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/push/push_service.dart';
import '../core/reminders.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../screens/profile_screen.dart';
import '../state/auth_controller.dart';
import '../state/theme_controller.dart';
import 'd_avatar.dart';
import 'd_brand_card.dart';
import 'd_push_status.dart';

/// Общий header пяти корневых вкладок (раздел 8): логотип и уровень
/// членства слева, уведомления и аватар справа. Скроллится вместе
/// с содержимым — за это отвечает DAppScaffold.
class DHeader extends StatelessWidget {
  const DHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final resident = context.watch<AuthController>().resident;
    final tier = resident?.tierLabel ?? 'Экосистема';

    return Row(
      children: [
        // Знак из брендбука: монохромный файл тонируется акцентом,
        // сам логотип не перерисован и не искажён
        Image.asset(
          'assets/brand/logo_mark.png',
          width: 34,
          height: 34,
          color: DColors.of(context).accent,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(width: DSpace.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ДОСТИГАТОР',
              style: TextStyle(
                fontFamily: 'Stolzl',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: DColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              tier.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Stolzl',
                fontSize: 8.5,
                fontWeight: FontWeight.w400,
                letterSpacing: 2.4,
                color: DColors.of(context).accent,
              ),
            ),
          ],
        ),
        const Spacer(),
        _ThemeToggle(),
        IconButton(
          onPressed: () => _openNotifications(context),
          icon: const Icon(Icons.notifications_none, size: 24),
          color: DColors.of(context).textPrimary,
          tooltip: 'Уведомления',
        ),
        const SizedBox(width: 2),
        Semantics(
          button: true,
          label: 'Профиль',
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            customBorder: const CircleBorder(),
            // Аватар 38px, но цель нажатия обязана быть не меньше 44 —
            // добиваем областью нажатия, а не размером картинки
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DUserAvatar(
                name: resident?.name ?? '',
                photoUrl: resident?.avatarUrl,
                size: 38,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Центра уведомлений на сервере нет — фиктивную ленту не рисуем.
  /// Показываем настоящее состояние напоминаний о чек-ине.
  void _openNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

/// Переключатель темы. Значок показывает, куда переключимся, а не где мы:
/// в тёмной теме — солнце, в светлой — луна. Так же ведут себя системные
/// переключатели, и человеку не нужно гадать.
class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final c = DColors.of(context);

    return IconButton(
      onPressed: theme.toggle,
      icon: Icon(
        theme.isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        size: 23,
      ),
      color: c.textPrimary,
      tooltip: theme.isLight ? 'Тёмная тема' : 'Светлая тема',
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    Reminders.isGranted().then((v) {
      if (mounted) setState(() => _granted = v);
    });
  }

  Future<void> _enable() async {
    await Reminders.requestPermission();
    final granted = await Reminders.isGranted();
    if (mounted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DSpace.page,
          DSpace.lg,
          DSpace.page,
          DSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Уведомления', style: DText.of(context).h2),
            const SizedBox(height: DSpace.md),
            if (context.read<PushService?>() != null)
              DBrandCard(
                background: DColors.of(context).surface2,
                child: const DPushStatus(),
              )
            else
              DBrandCard(
                background: DColors.of(context).surface2,
                child: switch (_granted) {
                  null => Text(
                    'Проверяем…',
                    style: DText.of(context).bodyMuted,
                  ),
                  true => Text(
                    'Напоминания о check-in включены: пятница утром '
                    'и воскресенье вечером, если отчёт ещё не отправлен.',
                    style: DText.of(context).body,
                  ),
                  false => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Напоминания о еженедельном check-in отключены.',
                        style: DText.of(context).body,
                      ),
                      const SizedBox(height: DSpace.md),
                      FilledButton(
                        onPressed: _enable,
                        child: const Text('Разрешить напоминания'),
                      ),
                    ],
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }
}

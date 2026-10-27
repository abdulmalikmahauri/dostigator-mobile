import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/push/push_channel.dart';
import '../core/push/push_service.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'd_primary_button.dart';
import 'd_states.dart';

/// Уведомления в браузере: что с ними сейчас и что сделать, чтобы
/// они приходили. Только содержимое — карточку вокруг рисует экран.
///
/// Показывается в веб-версии. В приложении на телефоне напоминания
/// ставит само устройство, и там свой блок.
class DPushStatus extends StatefulWidget {
  const DPushStatus({super.key});

  @override
  State<DPushStatus> createState() => _DPushStatusState();
}

class _DPushStatusState extends State<DPushStatus> with WidgetsBindingObserver {
  PushState? _state;

  /// Ключ сервера получен — кнопку «Включить» можно показывать.
  bool _ready = false;
  bool _busy = false;
  String? _error;

  PushService? get _push => context.read<PushService?>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Человек мог сходить в настройки и разрешить уведомления там —
  /// по возвращении показываем то, что есть на самом деле.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final push = _push;
    if (push == null) return;

    try {
      final state = await push.state();

      // Ключ сервера берём заранее: в момент нажатия идти за ним поздно —
      // айфон не покажет вопрос о разрешении после паузы
      final ready = state == PushState.prompt ? await push.prepare() : true;

      if (!mounted) return;

      setState(() {
        _state = state;
        _ready = ready;
      });
    } on PushException {
      if (mounted) setState(() => _state = PushState.unsupported);
    }
  }

  Future<void> _retry() async {
    if (_busy) return;

    setState(() => _busy = true);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _enable() async {
    final push = _push;
    if (push == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = await push.enable();

      if (mounted) setState(() => _state = state);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PushException {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось включить уведомления. Закройте приложение, '
              'откройте снова и попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final error = _error;

    return switch (_state) {
      null => const DSkeleton(height: 15, width: 200),

      PushState.granted => Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: c.accent, size: 18),
          const SizedBox(width: DSpace.sm),
          Expanded(
            child: Text(
              'Уведомления включены: напомним о чек-ине и о взносе.',
              style: t.body,
            ),
          ),
        ],
      ),

      PushState.prompt when !_ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Не получилось подготовить уведомления — похоже, нет связи. '
            'Проверьте интернет и повторите.',
            style: t.bodyMuted,
          ),
          const SizedBox(height: DSpace.md),
          OutlinedButton(
            onPressed: _busy ? null : _retry,
            child: const Text('Повторить'),
          ),
        ],
      ),

      PushState.prompt => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Включите уведомления, чтобы не пропустить еженедельный '
            'чек-ин и срок взноса.',
            style: t.bodyMuted,
          ),
          if (error != null) ...[
            const SizedBox(height: DSpace.sm),
            Text(error, style: t.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: DSpace.md),
          DPrimaryButton(
            label: 'Включить уведомления',
            loading: _busy,
            onPressed: _enable,
          ),
        ],
      ),

      PushState.needsInstall => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'На айфоне уведомления приходят только в приложение '
            'на экране «Домой». Поставить его — минута:',
            style: t.bodyMuted,
          ),
          const SizedBox(height: DSpace.sm),
          Text('1. Нажмите «Поделиться» внизу Safari.', style: t.body),
          const SizedBox(height: DSpace.xs),
          Text('2. Выберите «На экран «Домой»».', style: t.body),
          const SizedBox(height: DSpace.xs),
          Text(
            '3. Откройте «Достигатор» с новой иконки и включите '
            'уведомления здесь же.',
            style: t.body,
          ),
        ],
      ),

      PushState.denied => Text(
        'Уведомления запрещены. Разрешите их для «Достигатора» '
        'в настройках телефона или браузера и вернитесь сюда.',
        style: t.bodyMuted,
      ),

      PushState.unsupported => Text(
        'Этот браузер не умеет показывать уведомления. '
        'Откройте приложение в Chrome или Safari.',
        style: t.bodyMuted,
      ),
    };
  }
}

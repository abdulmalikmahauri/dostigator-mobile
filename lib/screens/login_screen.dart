import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../state/auth_controller.dart';
import '../widgets/d_background.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_primary_button.dart';

/// Телефон организатора клуба: восстановления пароля в продукте нет,
/// поэтому это единственный канал, если доступ утерян.
const _organizerPhonePretty = '+7 900 000 00 01';
const _organizerPhoneRaw = '+79000000001';

/// Экран входа (раздел 27 спецификации). Без bottom nav: пользователь ещё
/// не в приложении. Навигацию после успеха делает main.dart по AuthStage.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DBackground(
        // Клин не включаем: на экране входа геометрия отвлекала бы от формы
        pattern: true,
        wedge: false,
        child: SafeArea(
          // LayoutBuilder + IntrinsicHeight: Spacer-ы держат логотип в верхней
          // трети, а при открытой клавиатуре экран остаётся прокручиваемым
          child: LayoutBuilder(
            builder: (context, viewport) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: DSpace.page),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: IntrinsicHeight(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Spacer(flex: 2),
                            _BrandBlock(),
                            Spacer(),
                            _SignInCard(),
                            Spacer(flex: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Верхняя треть: знак бренда, словесный знак и короткая подпись.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Монохромный знак из брендбука тонируется акцентом — сам файл
        // не перерисовываем и не искажаем
        Image.asset(
          'assets/brand/logo_mark.png',
          width: 56,
          height: 56,
          color: DColors.of(context).accent,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(height: DSpace.md),
        // Словесный знак — часть фирменного начертания, капс здесь
        // брендовый, а не типографическое решение интерфейса
        Text(
          'ДОСТИГАТОР',
          style: TextStyle(
            fontFamily: 'Stolzl',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
            color: DColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: DSpace.xs),
        Text('Экосистема резидентов', style: DText.of(context).bodyMuted),
      ],
    );
  }
}

class _SignInCard extends StatefulWidget {
  const _SignInCard();

  @override
  State<_SignInCard> createState() => _SignInCardState();
}

class _SignInCardState extends State<_SignInCard> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscured = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Пустую форму не отправляем: запрос заведомо вернёт ошибку
  /// и лишь потратит попытку входа.
  bool get _filled =>
      _login.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (!_filled || auth.busy) return;

    FocusScope.of(context).unfocus();
    // Сервер отвечает одинаково на незнакомый логин и неверный пароль —
    // просто показываем auth.error, не пытаясь различить причины
    final signedIn = await auth.signIn(_login.text, _password.text);

    // Вход удался — даём телефону и браузеру знак, что эту пару можно
    // запомнить: после него система сама спросит «Сохранить пароль?».
    // При ошибке молчим: неверный пароль подставлялся бы снова и снова.
    if (signedIn) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Вход в приложение', style: DText.of(context).h2),
          const SizedBox(height: DSpace.lg),

          // Одна группа на оба поля: только так телефон понимает, что
          // логин и пароль — пара, и предлагает сохранить её в своём
          // хранилище паролей, а в следующий раз подставить.
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _login,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  style: DText.of(context).body,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Телефон или e-mail',
                    hintText: '+7 928 000 00 00',
                  ),
                ),

                const SizedBox(height: DSpace.md),

                TextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: _obscured,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  style: DText.of(context).body,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    suffixIcon: IconButton(
                      // Пароль диктуют по телефону и вводят с ошибками —
                      // без возможности его увидеть вход превращается
                      // в лотерею
                      onPressed: () => setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Показать пароль' : 'Скрыть пароль',
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: DColors.of(context).textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Компактная строка ошибки: DErrorState здесь избыточен —
          // повтор и так делается той же кнопкой «Войти»
          if (auth.error != null) ...[
            const SizedBox(height: DSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: DColors.of(context).danger,
                ),
                const SizedBox(width: DSpace.sm),
                Expanded(
                  child: Text(
                    auth.error!,
                    style: DText.of(
                      context,
                    ).caption.copyWith(color: DColors.of(context).danger),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: DSpace.lg),

          DPrimaryButton(
            label: 'Войти',
            loading: auth.busy,
            onPressed: _filled ? _submit : null,
          ),

          const SizedBox(height: DSpace.xs),

          TextButton(
            onPressed: () => _showForgotPassword(context),
            child: const Text('Забыли пароль?'),
          ),
        ],
      ),
    );
  }

  /// Автоматического сброса пароля нет (backend его не поддерживает),
  /// поэтому вместо reset-формы — контакт организатора клуба.
  void _showForgotPassword(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Забыли пароль?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Обратитесь к организатору клуба — он выдаст новый пароль. '
              'Восстановить его самостоятельно нельзя.',
              style: DText.of(context).bodyMuted,
            ),
            const SizedBox(height: DSpace.md),
            // SelectableText: номер можно выделить и скопировать частично,
            // если системное копирование удобнее кнопки
            SelectableText(
              _organizerPhonePretty,
              style: DText.of(
                context,
              ).cardTitle.copyWith(color: DColors.of(context).accent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Не ждём ответа платформы: копирование мгновенно, а ожидание
              // подвесило бы закрытие диалога, если канал не ответит
              Clipboard.setData(const ClipboardData(text: _organizerPhoneRaw));
              Navigator.of(ctx).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Номер скопирован')),
              );
            },
            child: const Text('Скопировать номер'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}

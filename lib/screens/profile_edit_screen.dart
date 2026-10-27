import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../state/auth_controller.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_sub_scaffold.dart';

/// Правка своих данных. Раньше их менял только организатор.
///
/// Телефона здесь нет намеренно: он служит логином, и сменить его
/// может только организатор — иначе человек рискует остаться без входа.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _city = TextEditingController();
  final _telegram = TextEditingController();
  final _whatsapp = TextEditingController();
  final _business = TextEditingController();
  final _niche = TextEditingController();
  final _description = TextEditingController();
  final _employees = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _canHelp = TextEditingController();
  final _lookingFor = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final resident = context.read<AuthController>().resident;
    final profile = resident?.profile;

    _name.text = resident?.name ?? '';
    _city.text = resident?.city ?? '';
    _telegram.text = resident?.telegram ?? '';
    _whatsapp.text = resident?.whatsapp ?? '';
    _business.text = profile?.businessName ?? '';
    _niche.text = profile?.niche ?? '';
    _description.text = profile?.description ?? '';
    _employees.text = profile?.employeesCount?.toString() ?? '';
    _website.text = profile?.website ?? '';
    _instagram.text = profile?.instagram ?? '';
    _canHelp.text = profile?.canHelp ?? '';
    _lookingFor.text = profile?.lookingFor ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _city,
      _telegram,
      _whatsapp,
      _business,
      _niche,
      _description,
      _employees,
      _website,
      _instagram,
      _canHelp,
      _lookingFor,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Пустое поле уходит на сервер как «нет значения», а не пропускается:
  /// иначе стёртый текст возвращался бы после сохранения.
  static String? _text(TextEditingController c) {
    final value = c.text.trim();

    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final error = await context.read<AuthController>().updateProfile({
      'name': _name.text.trim(),
      'city': _text(_city),
      'telegram': _text(_telegram),
      'whatsapp': _text(_whatsapp),
      'business_name': _text(_business),
      'niche': _text(_niche),
      'description': _text(_description),
      'employees_count': int.tryParse(_employees.text.trim()),
      'website': _text(_website),
      'instagram': _text(_instagram),
      'can_help': _text(_canHelp),
      'looking_for': _text(_lookingFor),
    });

    if (!mounted) return;

    if (error != null) {
      // Форма остаётся заполненной: человек правит одно поле,
      // а не набирает всё заново
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('Данные сохранены')));
    await navigator.maybePop();

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final resident = context.watch<AuthController>().resident;
    final t = DText.of(context);
    final c = DColors.of(context);
    final error = _error;

    return Form(
      key: _formKey,
      child: DSubScaffold(
        title: 'Мои данные',
        children: [
          const DSectionLabel('О себе'),
          const SizedBox(height: DSpace.sm),
          TextFormField(
            key: const Key('profile-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Имя и фамилия'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Укажите имя' : null,
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-city'),
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Город'),
          ),
          const SizedBox(height: DSpace.md),
          Text(
            'Телефон для входа: ${resident?.phonePretty ?? resident?.phone ?? '—'}. '
            'Его меняет организатор.',
            style: t.caption,
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Как с вами связаться'),
          const SizedBox(height: DSpace.sm),
          TextFormField(
            key: const Key('profile-whatsapp'),
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp',
              hintText: '+7 928 000 00 00',
            ),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-telegram'),
            controller: _telegram,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Telegram',
              hintText: '@имя',
            ),
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Бизнес'),
          const SizedBox(height: DSpace.sm),
          TextFormField(
            key: const Key('profile-business'),
            controller: _business,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Компания'),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-niche'),
            controller: _niche,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ниша',
              hintText: 'Общепит, строительство, медицина',
            ),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-description'),
            controller: _description,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'О бизнесе'),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-employees'),
            controller: _employees,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(labelText: 'Сотрудников'),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-website'),
            controller: _website,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Сайт'),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-instagram'),
            controller: _instagram,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Instagram',
              hintText: 'имя или ссылка',
            ),
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Для клуба'),
          const SizedBox(height: DSpace.sm),
          TextFormField(
            key: const Key('profile-can-help'),
            controller: _canHelp,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Чем могу быть полезен',
            ),
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            key: const Key('profile-looking-for'),
            controller: _lookingFor,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Что ищу'),
          ),
          const SizedBox(height: DSpace.sm),
          Text(
            'Что из этого видят другие резиденты, настраивается '
            'в профиле, в блоке «Приватность».',
            style: t.caption,
          ),

          // Кнопка — последней строкой формы, как и в форме цели
          const SizedBox(height: DSpace.xl),
          if (error != null) ...[
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: c.danger),
                const SizedBox(width: DSpace.sm),
                Expanded(
                  child: Text(
                    error,
                    style: t.caption.copyWith(color: c.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DSpace.sm),
          ],
          DPrimaryButton(
            label: 'Сохранить',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

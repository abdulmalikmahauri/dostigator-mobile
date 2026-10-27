import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/spacing.dart';
import '../design/typography.dart';

/// Что выбрал человек в окне количества.
sealed class AmountChoice {
  const AmountChoice();
}

final class AmountEntered extends AmountChoice {
  const AmountEntered(this.value);

  final int value;
}

/// «Снять отметку» — то же, что ноль, но словами, а не цифрой.
final class AmountCleared extends AmountChoice {
  const AmountCleared();
}

/// Окно с одним числом: сколько сделано сегодня, своя норма в привычке.
/// null — передумал и закрыл окно.
Future<AmountChoice?> showAmountDialog(
  BuildContext context, {
  required String title,
  required int initial,
  required String confirmLabel,
  String? unit,
  String? message,
  bool canClear = false,
}) {
  return showDialog<AmountChoice>(
    context: context,
    builder: (_) => _AmountDialog(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
      unit: unit,
      message: message,
      canClear: canClear,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.canClear,
    this.unit,
    this.message,
  });

  final String title;
  final int initial;
  final String confirmLabel;
  final String? unit;
  final String? message;
  final bool canClear;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}')
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: '${widget.initial}'.length,
    );
  String? _error;

  /// Верхний предел — как на сервере.
  static const _max = 100000;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final value = int.tryParse(_controller.text.trim());

    if (value == null || value < 1 || value > _max) {
      setState(() => _error = 'Число от 1 до 100 000');
      return;
    }

    Navigator.of(context).pop(AmountEntered(value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!, style: DText.of(context).bodyMuted),
            const SizedBox(height: DSpace.md),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _confirm(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Сколько',
              suffixText: widget.unit,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.canClear)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const AmountCleared()),
            child: const Text('Снять отметку'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

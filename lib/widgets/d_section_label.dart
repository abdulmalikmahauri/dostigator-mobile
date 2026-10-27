import 'package:flutter/material.dart';

import '../design/typography.dart';

/// Маленькая зелёная подпись капсом: «ФОКУС НЕДЕЛИ», «МОИ ОБЯЗАТЕЛЬСТВА».
/// Единственное место в интерфейсе, где капс разрешён.
class DSectionLabel extends StatelessWidget {
  const DSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: DText.of(context).micro);
  }
}

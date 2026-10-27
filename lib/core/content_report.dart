import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/spacing.dart';
import '../design/typography.dart';
import 'api_client.dart';

/// Что можно отправить в жалобе: общая привычка или задача.
enum ReportedContent { habit, task }

/// Пожаловаться на чужую общую привычку или задачу. Решают организаторы:
/// скрыть или оставить. Так App Store требует для всего, что пишут
/// сами пользователи.
Future<void> reportContent(
  BuildContext context, {
  required ReportedContent type,
  required int id,
  required String title,
}) async {
  final api = context.read<ApiClient>();
  final messenger = ScaffoldMessenger.of(context);

  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _ReportDialog(title: title),
  );

  if (reason == null) return;

  try {
    await api.post('/reports', {
      'type': type.name,
      'id': id,
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Спасибо, организаторы посмотрят')),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.title});

  final String title;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Пожаловаться'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '«${widget.title}» посмотрят организаторы клуба '
            'и решат, скрыть ли это.',
            style: DText.of(context).bodyMuted,
          ),
          const SizedBox(height: DSpace.md),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Что не так — необязательно',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: const Text('Отправить'),
        ),
      ],
    );
  }
}

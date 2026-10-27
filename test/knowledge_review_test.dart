import 'package:dostigator/widgets/video_embed/video_hosts.dart';
import 'package:dostigator/state/knowledge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/manual_adapter.dart';

void main() {
  group('Куда пускает плеер', () {
    test('только https на VK Видео и Rutube', () {
      expect(VideoHosts.isAllowed('https://rutube.ru/play/embed/abc'), isTrue);
      expect(
        VideoHosts.isAllowed('https://vkvideo.ru/video_ext.php?oid=1&id=2'),
        isTrue,
      );
      expect(VideoHosts.isAllowed('https://m.vk.com/video1_2'), isTrue);

      expect(VideoHosts.isAllowed('http://rutube.ru/play/embed/abc'), isFalse);
      expect(VideoHosts.isAllowed('https://evilrutube.ru/x'), isFalse);
      expect(VideoHosts.isAllowed('https://rutube.ru.evil.io/x'), isFalse);
      expect(VideoHosts.isAllowed('https://rutube.ru@evil.io/x'), isFalse);
      expect(VideoHosts.isAllowed('javascript:alert(1)'), isFalse);
      expect(VideoHosts.isAllowed(''), isFalse);
    });

    /// Служебные окна внутри плеера (реклама, сеть доставки) — его дело;
    /// а переход всей страницы на чужой сайт — только снаружи.
    test('решение по переходу', () {
      expect(
        VideoHosts.decide('https://cdn.example/frame', isMainFrame: false),
        NavDecision.allow,
      );
      expect(
        VideoHosts.decide('https://rutube.ru/video/abc/', isMainFrame: true),
        NavDecision.allow,
      );
      expect(
        VideoHosts.decide('https://example.com/ad', isMainFrame: true),
        NavDecision.openOutside,
      );
      expect(
        VideoHosts.decide('intent://scan#Intent;end', isMainFrame: true),
        NavDecision.block,
      );
    });
  });

  test('отметка «изучено» не ждёт перечитывания списка', () async {
    final (:api, :adapter) = manualApi();
    final c = KnowledgeController(api);
    final before = c.progressVersion;

    final pending = c.mark(11, completed: true);
    await adapter.waitFor(1);
    adapter.reply((o) => o.path == '/lessons/11/complete', {
      'data': {
        'id': 11,
        'course_id': 1,
        'title': 'Отчёт о прибылях',
        'is_available': true,
        'is_completed': true,
      },
    });

    // Отметка вернулась, хотя список ещё перечитывается
    final lesson = await pending;
    expect(lesson.isCompleted, isTrue);
    expect(c.progressVersion, before + 1);

    await adapter.waitFor(2);
    adapter.reply((o) => o.path == '/courses', {'data': []});
  });
}

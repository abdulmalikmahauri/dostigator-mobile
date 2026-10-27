import 'package:dostigator/widgets/d_avatar_cropper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Обрезка фото — чистая арифметика: по сдвигу и увеличению картинки
/// в окне понять, какой квадрат исходного снимка попал в круг.
void main() {
  // Горизонтальный снимок 2000×1000 в квадратном окне 300×300.
  // Без увеличения он вписан по высоте: в окно попадает квадрат 1000×1000.
  const image = Size(2000, 1000);
  const viewport = 300.0;

  test('сразу после открытия в круге — середина снимка', () {
    final start = initialCropTransform(viewport: viewport, image: image);

    expect(
      cropRect(transform: start, viewport: viewport, image: image),
      const Rect.fromLTWH(500, 0, 1000, 1000),
    );
  });

  test('у вертикального снимка середина берётся по высоте', () {
    const portrait = Size(1000, 3000);
    final start = initialCropTransform(viewport: viewport, image: portrait);

    expect(
      cropRect(transform: start, viewport: viewport, image: portrait),
      const Rect.fromLTWH(0, 1000, 1000, 1000),
    );
  });

  test('увеличение вдвое сужает область вдвое', () {
    final zoomed = Matrix4.identity()
      ..translateByDouble(-600, -150, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);

    expect(
      cropRect(transform: zoomed, viewport: viewport, image: image),
      const Rect.fromLTWH(1000, 250, 500, 500),
    );
  });

  test('сдвиг к левому краю показывает левую часть', () {
    expect(
      cropRect(transform: Matrix4.identity(), viewport: viewport, image: image),
      const Rect.fromLTWH(0, 0, 1000, 1000),
    );
  });

  /// Жест может на мгновение увести картинку за край — в файл
  /// пустота попасть не должна.
  test('область не выходит за края снимка', () {
    final overshoot = Matrix4.identity()..translateByDouble(-900, 80, 0, 1);

    final rect = cropRect(
      transform: overshoot,
      viewport: viewport,
      image: image,
    );

    expect(rect, const Rect.fromLTWH(1000, 0, 1000, 1000));
  });

  test('сторона итогового файла не больше исходной области', () {
    expect(outputSide(const Rect.fromLTWH(0, 0, 1000, 1000)), 800);
    expect(outputSide(const Rect.fromLTWH(0, 0, 320, 320)), 320);
  });
}

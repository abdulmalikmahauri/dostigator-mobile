import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'd_primary_button.dart';

/// Наибольшая сторона файла, который уходит на сервер. Каталогу хватает
/// 800 точек; сервер всё равно пересоберёт фото в аккуратный JPEG.
const _maxOutputSide = 800;

/// Наибольшее увеличение на экране обрезки.
const _maxZoom = 6.0;

/// Сторона окна обрезки: не шире формы и не меньше, чем удобно пальцам.
const _maxViewport = 420.0;
const _minViewport = 160.0;

/// Сколько высоты экрана занято шапкой, подсказкой и кнопкой «Готово».
/// Окно обрезки обязано быть квадратом и целиком помещаться в остаток:
/// иначе в файл попадёт не то, что человек видел в круге.
const _reservedHeight = 250.0;

/// Положение снимка сразу после открытия: в круге — его середина.
///
/// Без увеличения снимок вписан в окно по короткой стороне, поэтому
/// длинная выступает за края — её и сдвигаем на половину выступа.
Matrix4 initialCropTransform({required double viewport, required Size image}) {
  final shortSide = math.min(image.width, image.height);

  return Matrix4.translationValues(
    -(image.width * viewport / shortSide - viewport) / 2,
    -(image.height * viewport / shortSide - viewport) / 2,
    0,
  );
}

/// Какой квадрат исходного снимка (в его точках) сейчас виден в окне.
///
/// [transform] — сдвиг и увеличение, которые человек задал пальцами.
/// Результат не выходит за края снимка, даже если жест на мгновение
/// увёл картинку дальше: пустота в файл попасть не должна.
Rect cropRect({
  required Matrix4 transform,
  required double viewport,
  required Size image,
}) {
  final shortSide = math.min(image.width, image.height);
  final zoom = transform.getMaxScaleOnAxis();
  final shift = transform.getTranslation();

  // Сначала умножаем, потом делим: так целые размеры дают целый ответ
  final side = math.min(shortSide / zoom, shortSide);
  final left = -shift.x * shortSide / (zoom * viewport);
  final top = -shift.y * shortSide / (zoom * viewport);

  return Rect.fromLTWH(
    left.clamp(0.0, image.width - side),
    top.clamp(0.0, image.height - side),
    side,
    side,
  );
}

/// Сторона итогового файла: растягивать маленький фрагмент незачем.
int outputSide(Rect area) => math.min(area.width.round(), _maxOutputSide);

/// Сторона квадратного окна обрезки для экрана заданного размера.
double cropViewport(Size screen, EdgeInsets padding) {
  final byWidth = screen.width - DSpace.page * 2;
  final byHeight = screen.height - padding.vertical - _reservedHeight;

  return math
      .min(math.min(byWidth, byHeight), _maxViewport)
      .clamp(_minViewport, _maxViewport);
}

/// Вырезает [area] из снимка и отдаёт его как PNG.
Future<Uint8List> cropToPng(ui.Image image, Rect area) async {
  final side = outputSide(area);
  final recorder = ui.PictureRecorder();

  Canvas(recorder).drawImageRect(
    image,
    area,
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );

  final picture = recorder.endRecording();

  try {
    final cropped = await picture.toImage(side, side);

    try {
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) {
        throw StateError('Не удалось собрать файл фото');
      }

      return data.buffer.asUint8List();
    } finally {
      cropped.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Экран обрезки фото под круглую рамку аватара: снимок двигают и
/// увеличивают пальцами, в круге остаётся то, что увидят в каталоге.
///
/// Написан на средствах самого Flutter, без сторонних пакетов: одинаково
/// работает на андроиде, айфоне и в браузере.
class DAvatarCropper extends StatefulWidget {
  const DAvatarCropper({super.key, required this.bytes});

  /// Исходный файл, как его отдала галерея.
  final Uint8List bytes;

  /// Открывает экран. Возвращает PNG выбранной области
  /// либо null, если человек передумал.
  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DAvatarCropper(bytes: bytes),
      ),
    );
  }

  @override
  State<DAvatarCropper> createState() => _DAvatarCropperState();
}

class _DAvatarCropperState extends State<DAvatarCropper> {
  final _transform = TransformationController();

  ui.Image? _image;
  double _viewport = 0;
  bool _unreadable = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Размер окна зависит от экрана: при повороте телефона он меняется,
    // и снимок возвращается в исходное положение
    final viewport = cropViewport(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
    );

    if (viewport != _viewport) {
      _viewport = viewport;
      _reset();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    ui.Codec? codec;

    try {
      codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();

      if (!mounted) {
        frame.image.dispose();
        return;
      }

      _image = frame.image;
      _reset();
      setState(() {});
    } on Exception {
      // Файл оказался не картинкой или в формате, который телефон не читает
      if (mounted) setState(() => _unreadable = true);
    } finally {
      codec?.dispose();
    }
  }

  /// Возвращает снимок в исходное положение — серединой в круг.
  void _reset() {
    final image = _image;
    if (image == null || _viewport <= 0) return;

    _transform.value = initialCropTransform(
      viewport: _viewport,
      image: Size(image.width.toDouble(), image.height.toDouble()),
    );
  }

  Future<void> _done() async {
    final image = _image;
    if (image == null || _saving) return;

    setState(() => _saving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final Uint8List bytes;

    try {
      bytes = await cropToPng(
        image,
        cropRect(
          transform: _transform.value,
          viewport: _viewport,
          image: Size(image.width.toDouble(), image.height.toDouble()),
        ),
      );
    } on Object {
      // Сборка файла идёт в графическом движке и на разных платформах
      // падает по-разному — в том числе не исключениями Dart. Что бы ни
      // случилось, человек должен увидеть отказ, а не вечный спиннер.
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось обработать фото')),
        );
      }
      return;
    }

    if (!mounted) return;

    navigator.pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);
    final image = _image;

    // Пока фото собирается, уйти с экрана нельзя: иначе готовый файл
    // закрыл бы уже не этот экран, а профиль под ним
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, DSpace.page, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, size: 24),
                      color: c.textPrimary,
                      tooltip: 'Отмена',
                    ),
                    const SizedBox(width: 2),
                    Expanded(child: Text('Фото профиля', style: t.h2)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: _unreadable
                      ? Padding(
                          padding: const EdgeInsets.all(DSpace.page),
                          child: Text(
                            'Это фото открыть не получилось. '
                            'Выберите другое — подойдут JPEG и PNG.',
                            style: t.bodyMuted,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : image == null
                      ? CircularProgressIndicator(color: c.accent)
                      : _CropArea(
                          image: image,
                          viewport: _viewport,
                          transform: _transform,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DSpace.page,
                  DSpace.sm,
                  DSpace.page,
                  DSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Двигайте и увеличивайте фото двумя пальцами. '
                      'В каталоге будет видно то, что в круге.',
                      style: t.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DSpace.md),
                    DPrimaryButton(
                      label: 'Готово',
                      loading: _saving,
                      onPressed: image == null ? null : _done,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Окно обрезки: снимок под жестами и затемнение с круглым вырезом поверх.
class _CropArea extends StatelessWidget {
  const _CropArea({
    required this.image,
    required this.viewport,
    required this.transform,
  });

  final ui.Image image;
  final double viewport;
  final TransformationController transform;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final shortSide = math.min(image.width, image.height);

    // Квадрат строго заданного размера — даже если места меньше: расчёт
    // обрезки опирается на него, и сжатое окно дало бы не тот кадр
    return OverflowBox(
      minWidth: viewport,
      maxWidth: viewport,
      minHeight: viewport,
      maxHeight: viewport,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: InteractiveViewer(
              transformationController: transform,
              // Снимок крупнее окна и не может отойти от его краёв:
              // пустых полей в круге не бывает
              constrained: false,
              boundaryMargin: EdgeInsets.zero,
              minScale: 1,
              maxScale: _maxZoom,
              child: SizedBox(
                width: image.width * viewport / shortSide,
                height: image.height * viewport / shortSide,
                child: RawImage(image: image, fit: BoxFit.fill),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _CircleMask(scrim: c.background, ring: c.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Затемнение вокруг круга: то, что вне его, в аватар не попадёт.
class _CircleMask extends CustomPainter {
  const _CircleMask({required this.scrim, required this.ring});

  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(frame),
        Path()..addOval(frame),
      ),
      Paint()..color = scrim.withValues(alpha: 0.72),
    );

    canvas.drawOval(
      frame.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_CircleMask old) => old.scrim != scrim || old.ring != ring;
}

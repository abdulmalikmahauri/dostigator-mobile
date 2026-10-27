import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// QR-панель (раздел 41): используется картой резидента и билетом события,
/// но токены у них разные и между системами не переиспользуются.
///
/// Модули QR тёмные на белом — инвертированный «зелёный на тёмном»
/// красив, но часть сканеров его не читает, а карта существует,
/// чтобы её читали.
class DQrCard extends StatelessWidget {
  const DQrCard({super.key, required this.data, this.size = 208, this.caption});

  final String data;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(DSpace.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DRadius.card),
            border: Border.all(
              color: DColors.of(context).accentBorder,
              width: 1,
            ),
          ),
          child: QrImageView(
            data: data,
            size: size,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: DColors.of(context).brandBlack,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: DColors.of(context).brandBlack,
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: DSpace.sm),
          Text(
            caption!,
            style: DText.of(context).caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Preserves the source asset's material while excluding transparent margins.
class SkinAsset extends StatefulWidget {
  const SkinAsset(this.name, this.source, {super.key, this.wheelOffset = 0});
  final String name;
  final Rect source;
  final double wheelOffset;
  @override
  State<SkinAsset> createState() => _SkinAssetState();
}

class _SkinAssetState extends State<SkinAsset> {
  ui.Image? image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await rootBundle.load('assets/images/${widget.name}');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final decoded = (await codec.getNextFrame()).image;
    codec.dispose();
    if (!mounted) {
      decoded.dispose();
      return;
    }
    setState(() => image = decoded);
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: image == null
        ? null
        : _SkinPainter(image!, widget.source, widget.wheelOffset),
    child: const SizedBox.expand(),
  );
}

class _SkinPainter extends CustomPainter {
  _SkinPainter(this.image, this.source, this.offset);
  final ui.Image image;
  final Rect source;
  final double offset;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, source, Offset.zero & size, paint);
    if (offset != 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          size.width * .25,
          size.height * .13,
          size.width * .74,
          size.height * .75,
        ),
      );
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, offset % 8, size.width, size.height),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SkinPainter old) =>
      image != old.image || source != old.source || offset != old.offset;
}

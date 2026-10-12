import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/practice_input.dart';
import '../../ui/widgets/skin_asset.dart';

class PowerGauge extends StatefulWidget {
  const PowerGauge({super.key, required this.game});
  final PracticeInput game;
  @override
  State<PowerGauge> createState() => _PowerGaugeState();
}

class _PowerGaugeState extends State<PowerGauge> {
  double _power = 0, _startY = 0;
  int? _pointer;
  void _set(double value) {
    setState(() => _power = value.clamp(0, 1));
    widget.game.setPower(_power);
  }

  void _cancel() {
    _pointer = null;
    _set(0);
  }

  Future<void> _release() async {
    _pointer = null;
    if (_power >= .015 && widget.game.canAim) {
      await widget.game.shoot();
    }
    if (mounted) _set(0);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.maxHeight;
      final handleHeight = (constraints.maxWidth * .86).clamp(40.0, 75.0);
      return Semantics(
        label: '力度滑条，向下拉杆松手出杆，滑回零取消',
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_pointer != null) {
              _cancel();
              return;
            }
            if (!widget.game.canAim) return;
            _pointer = event.pointer;
            _startY = event.localPosition.dy;
            _set(0);
          },
          onPointerMove: (event) {
            if (event.pointer == _pointer) {
              _set(
                (event.localPosition.dy - _startY) /
                    (height - handleHeight - 25).clamp(1.0, double.infinity),
              );
            }
          },
          onPointerUp: (event) {
            if (event.pointer == _pointer) unawaited(_release());
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) _cancel();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: SkinAsset(
                  'power-track.png',
                  Rect.fromLTWH(250, 28, 388, 1727),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * .12,
                right: constraints.maxWidth * .12,
                top: _power * (height - handleHeight - 30),
                height: handleHeight,
                child: const SkinAsset(
                  'power-handle.png',
                  Rect.fromLTWH(160, 215, 935, 830),
                ),
              ),
              if (_pointer != null)
                Positioned(
                  left: -46,
                  top: _power * (height - handleHeight - 30) + 10,
                  child: Text(
                    '${(_power * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

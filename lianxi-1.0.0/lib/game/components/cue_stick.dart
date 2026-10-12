import 'dart:ui' as ui;
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart';

import '../table_constants.dart';

enum CueStickState { hidden, aiming, pullingBack, striking }

class CueStick extends Component {
  CueStick();
  late final ui.Image _skin;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _skin = await Flame.images.load('cue-skin.png');
  }

  CueStickState state = CueStickState.hidden;
  Vector2 cueBallPosition = Vector2.zero();
  double aimAngle = 0;
  double pullBack = 0;
  double strikeProgress = 0;

  static const double stickLength = 125;
  static const double stickWidth = 0.65;
  static const double tipGap = TableConstants.ballRadius + 1.5;

  void showAiming(Vector2 cuePos, double angleRad) {
    state = CueStickState.aiming;
    cueBallPosition = cuePos.clone();
    aimAngle = angleRad;
    pullBack = 0;
  }

  void hide() {
    state = CueStickState.hidden;
  }

  Future<void> animateStrike(double powerRatio) async {
    if (state == CueStickState.hidden) return;
    state = CueStickState.pullingBack;
    pullBack = 8 + powerRatio * 18;

    await Future<void>.delayed(const Duration(milliseconds: 120));

    state = CueStickState.striking;
    strikeProgress = 0;

    const steps = 8;
    for (var i = 0; i <= steps; i++) {
      strikeProgress = i / steps;
      pullBack = (8 + powerRatio * 18) * (1 - strikeProgress);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }

    hide();
  }

  @override
  void render(Canvas canvas) {
    if (state == CueStickState.hidden) return;

    canvas.save();
    canvas.translate(cueBallPosition.x, cueBallPosition.y);
    canvas.rotate(aimAngle);

    final backOffset = tipGap + pullBack;
    final tipX = -backOffset;
    final buttX = tipX - stickLength;

    canvas.drawImageRect(
      _skin,
      const Rect.fromLTWH(6, 319, 2176, 74),
      Rect.fromLTRB(buttX, -2, tipX, 2),
      Paint()..filterQuality = FilterQuality.high,
    );

    canvas.restore();
  }
}

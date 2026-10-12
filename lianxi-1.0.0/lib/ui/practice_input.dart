import 'package:flutter/foundation.dart';
import 'package:flame/extensions.dart';

/// Input boundary shared by the practice controls and an engine adapter.
/// Power is normalized to 0..1; spin is a unit disc (positive y = low cue).
/// The adapter owns notifiers and must reject input while [canAim] is false.
abstract interface class PracticeInput {
  bool get canAim;
  Vector2 get aimDirection;
  ValueListenable<Vector2> get spinNotifier;
  void setAimDirection(Vector2 direction);
  void setPower(double value);
  void setSpinOffset(Vector2 offset);
  Future<void> shoot();
}

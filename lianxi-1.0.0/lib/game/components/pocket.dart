import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import 'ball.dart';

class Pocket extends BodyComponent with ContactCallbacks {
  Pocket({
    required this.index,
    required Vector2 center,
    required this.radius,
    required this.onBallPocketed,
  }) : _center = center.clone();

  final int index;
  final Vector2 _center;
  final double radius;
  final void Function(Ball ball, Pocket pocket) onBallPocketed;

  Vector2 get pocketCenter => _center;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..userData = this;

    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = _center;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    // Pocket visuals are drawn by Table; suppress default BodyComponent rendering
  }

  @override
  void beginContact(Object other, Contact contact) {
    // A sensor fires when ball and pocket circles merely overlap; require the
    // ball centre to pass into the mouth so two balls cannot fall in abreast.
    if (other is Ball &&
        !other.isPocketed &&
        (other.body.position - _center).length < radius * 0.6) {
      onBallPocketed(other, this);
    }
  }
}

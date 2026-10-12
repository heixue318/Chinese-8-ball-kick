import 'dart:ui' as ui;
import 'package:flame/flame.dart';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

import '../table_constants.dart';
import '../systems/table_geometry.dart';

class Table extends Component {
  Table({required this.world});

  final Forge2DWorld world;
  late final ui.Image _skin;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _skin = await Flame.images.load('table-reference-skin.png');
    _createCushions();
  }

  void _createCushions() {
    for (final (start, end) in TableGeometry.cushionSegments()) {
      world.add(CushionSegment(start: start, end: end));
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawImageRect(
      _skin,
      // Crop the transparent padding from the reference-style asset, while
      // preserving the 2:1 playing-table proportion.
      const Rect.fromLTWH(77, 40, 1620, 804),
      const Rect.fromLTRB(-139, -69.5, 139, 69.5),
      Paint()..filterQuality = FilterQuality.high,
    );
  }
}

class CushionSegment extends BodyComponent {
  CushionSegment({required this.start, required this.end});

  final Vector2 start;
  final Vector2 end;

  static const cushionMarker = _CushionMarker();

  @override
  void render(Canvas canvas) {}

  @override
  Body createBody() {
    final shape = EdgeShape()..set(start, end);
    final fixtureDef = FixtureDef(shape)
      ..restitution = TableConstants.cushionRestitution
      ..friction = TableConstants.cushionFriction
      ..userData = cushionMarker;
    return world.createBody(BodyDef(type: BodyType.static))
      ..createFixture(fixtureDef);
  }
}

class _CushionMarker {
  const _CushionMarker();
}

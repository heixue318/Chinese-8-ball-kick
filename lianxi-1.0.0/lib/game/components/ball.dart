import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/flame.dart';

import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

import '../table_constants.dart';

typedef BallContactCallback = void Function(Ball self, Object other);

class Ball extends BodyComponent with ContactCallbacks {
  Ball({required this.number, required Vector2 position, this.onContact})
    : _initialPosition = position.clone();

  final int number;
  ui.Image? _skin;
  ui.FragmentShader? _sphereShader;
  ui.Image? _numberDecal;
  static Future<ui.FragmentProgram>? _sphereProgram;
  static final Map<int, Future<ui.Image>> _numberDecals = {};
  static const _sheetCellWidth = 332.75;
  static const _sheetCellHeight = 295.5;
  static const _sheetCrop = 295.5;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _skin = await Flame.images.load('balls-reference-sheet.png');
    try {
      final program = await (_sphereProgram ??= ui.FragmentProgram.fromAsset(
        'shaders/ball_surface.frag',
      ));
      _sphereShader = program.fragmentShader();
      _numberDecal = await (_numberDecals[number] ??= _createNumberDecal(
        number,
      ));
    } catch (_) {
      // Keep the original sprite as a fallback on unsupported renderers.
    }
  }

  static Future<ui.Image> _createNumberDecal(int number) async {
    const size = 128.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(64, 64),
      58,
      Paint()..color = const Color(0xFFF8F7EF),
    );
    if (number != 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            color: const Color(0xFF161616),
            fontSize: number >= 10 ? 67 : 82,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );
    }
    return recorder.endRecording().toImage(128, 128);
  }

  final Vector2 _initialPosition;
  BallContactCallback? onContact;

  bool isPocketed = false;
  bool isVisible = true;
  bool isDragging = false;

  bool get isCueBall => number == 0;
  bool get is8Ball => number == 8;
  bool get isSolid => number >= 1 && number <= 7;
  bool get isStripe => number >= 9 && number <= 15;

  static const Map<int, Color> _colors = {
    0: Color(0xFFF1ECC8),
    1: Color(0xFFF9D923),
    2: Color(0xFF1565C0),
    3: Color(0xFFD32F2F),
    4: Color(0xFF7B1FA2),
    5: Color(0xFFFF8F00),
    6: Color(0xFF2E7D32),
    7: Color(0xFF880E4F),
    8: Color(0xFF1A1A1A),
    9: Color(0xFFF9D923),
    10: Color(0xFF1565C0),
    11: Color(0xFFD32F2F),
    12: Color(0xFF7B1FA2),
    13: Color(0xFFFF8F00),
    14: Color(0xFF2E7D32),
    15: Color(0xFF880E4F),
  };

  Color get ballColor => _colors[number] ?? const Color(0xFFCCCCCC);

  @override
  Body createBody() {
    final shape = CircleShape()..radius = TableConstants.ballRadius;

    final fixtureDef = FixtureDef(shape)
      ..restitution = TableConstants.ballRestitution
      ..friction = TableConstants.ballFriction
      ..density = TableConstants.ballDensity
      ..userData = this;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = _initialPosition
      ..linearDamping = TableConstants.rollingDamping
      ..angularDamping = 0.3
      ..bullet = true;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  bool _pendingDeactivation = false;
  final Vector2 _lastRollPosition = Vector2.zero();
  bool _hasRollPosition = false;
  double _qx = 0, _qy = 0, _qz = 0, _qw = 1;

  void _rotateSphere(double ax, double ay, double az, double angle) {
    if (angle.abs() < 0.00001) return;
    final sinHalf = math.sin(angle * .5);
    final dx = ax * sinHalf, dy = ay * sinHalf, dz = az * sinHalf;
    final dw = math.cos(angle * .5);
    final x = dw * _qx + dx * _qw + dy * _qz - dz * _qy;
    final y = dw * _qy - dx * _qz + dy * _qw + dz * _qx;
    final z = dw * _qz + dx * _qy - dy * _qx + dz * _qw;
    final w = dw * _qw - dx * _qx - dy * _qy - dz * _qz;
    final scale = 1 / math.sqrt(x * x + y * y + z * z + w * w);
    _qx = x * scale;
    _qy = y * scale;
    _qz = z * scale;
    _qw = w * scale;
  }

  void pocket() {
    isPocketed = true;
    isVisible = false;
    isDragging = false;
    body.setTransform(Vector2(-1000, -1000), 0);
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
    // Defer body deactivation to avoid mutating the world during collision iteration
    _pendingDeactivation = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pendingDeactivation) {
      _pendingDeactivation = false;
      body.setActive(false);
    }
    if (body.isActive && !isPocketed) {
      if (_hasRollPosition) {
        final movement = body.position - _lastRollPosition;
        final travel = movement.length;
        if (travel > 0.0005) {
          // No-slip rolling: the rotation axis lies across the travel
          // direction in the table plane, so the marking tumbles over the
          // sphere instead of spinning like a flat disk.
          _rotateSphere(
            movement.y / travel,
            -movement.x / travel,
            0,
            travel / TableConstants.ballRadius,
          );
        }
      }
      _rotateSphere(0, 0, 1, body.angularVelocity * dt);
      _lastRollPosition.setFrom(body.position);
      _hasRollPosition = true;

      // Finish the imperceptible tail promptly.  This also makes the next
      // stroke available as soon as the visible balls have stopped.
      final speed = body.linearVelocity.length;
      if (speed > 0 && speed < TableConstants.slowBallSpeed) {
        body.linearVelocity.scale(math.exp(-9.0 * dt));
      }
      if (body.linearVelocity.length < TableConstants.stopSpeed) {
        body.linearVelocity = Vector2.zero();
        body.angularVelocity = 0;
      } else if (body.angularVelocity.abs() > 0 &&
          body.angularVelocity.abs() < 0.2) {
        body.angularVelocity = 0;
      }
    }
  }

  void restoreForPlacement(Vector2 position) {
    _pendingDeactivation = false;
    isPocketed = false;
    isVisible = true;
    body.setActive(true);
    setPosition(position);
  }

  void setPosition(Vector2 position) {
    body.setTransform(position, body.angle);
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
    _lastRollPosition.setFrom(position);
    _hasRollPosition = true;
    _qx = 0;
    _qy = 0;
    _qz = 0;
    _qw = 1;
  }

  void reposition(Vector2 position) {
    _pendingDeactivation = false;
    isPocketed = false;
    isVisible = true;
    isDragging = false;
    body.setActive(true);
    setPosition(position);
  }

  void setDragging(bool dragging) {
    isDragging = dragging;
    if (dragging) {
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    onContact?.call(this, other);
  }

  bool get isMoving {
    if (isPocketed || !body.isActive) return false;
    return body.linearVelocity.length > TableConstants.stopSpeed;
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible || (isPocketed && !isDragging)) return;

    const center = Offset.zero;
    const r = TableConstants.ballRadius;
    final alpha = isDragging ? 0.55 : 1.0;
    if (_sphereShader != null && _numberDecal != null) {
      canvas.save();
      canvas.rotate(-body.angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, r * .72),
          width: r * 1.78,
          height: r * .46,
        ),
        Paint()..color = const Color(0x33000905),
      );
      final shader = _sphereShader!;
      final color = ballColor;
      shader.setFloat(0, r);
      shader.setFloat(1, _qx);
      shader.setFloat(2, _qy);
      shader.setFloat(3, _qz);
      shader.setFloat(4, _qw);
      shader.setFloat(5, color.r);
      shader.setFloat(6, color.g);
      shader.setFloat(7, color.b);
      shader.setFloat(8, isStripe ? 1 : 0);
      shader.setFloat(9, isCueBall ? 1 : 0);
      shader.setImageSampler(0, _numberDecal!);
      canvas.drawRect(
        Rect.fromCircle(center: Offset.zero, radius: r),
        Paint()
          ..shader = shader
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      canvas.restore();
      return;
    }
    if (_skin != null) {
      // The source sheet includes a baked-in, asymmetric shadow.  It rotated
      // with the rigid body and looked glued to the rolling ball.  Draw an
      // independent, table-fixed oval instead, then clip the sprite to its
      // spherical silhouette so that only the ball body is used.
      canvas.save();
      canvas.rotate(-body.angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, r * .72),
          width: r * 1.78,
          height: r * .46,
        ),
        Paint()
          ..shader =
              const RadialGradient(
                colors: [Color(0x65000905), Color(0x00000905)],
              ).createShader(
                Rect.fromCenter(
                  center: Offset(0, r * .72),
                  width: r * 1.78,
                  height: r * .46,
                ),
              )
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      canvas.restore();

      final row = number ~/ 4;
      final column = number % 4;
      final src = Rect.fromLTWH(
        column * _sheetCellWidth + (_sheetCellWidth - _sheetCrop) / 2,
        row * _sheetCellHeight,
        _sheetCrop,
        _sheetCrop,
      );
      // The crop includes the sprite's shadow; its ball body remains exactly
      // two physical radii wide after scaling.
      final scale = r * 2 / 202;
      final extent = _sheetCrop * scale;
      final dst = Rect.fromCenter(
        center: center,
        width: extent,
        height: extent,
      );
      canvas.save();
      // BodyComponent already applies the physics angle.  Replace it with the
      // distance-derived roll phase for the visible ball artwork.
      canvas.rotate(-body.angle);
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCircle(center: Offset(0, r * .06), radius: r * .98),
        ),
      );
      canvas.drawImageRect(
        _skin!,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      canvas.restore();
      return;
    }

    // Fallback for asset loading failures.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0.4, 0.7),
        width: r * 2.2,
        height: r * 1.2,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: const [Color(0x55000000), Color(0x00000000)],
            ).createShader(
              Rect.fromCenter(
                center: const Offset(0.4, 0.7),
                width: r * 2.2,
                height: r * 1.2,
              ),
            ),
    );

    // Draw ball body (no rotation — gradient stays fixed for 3D look)
    if (isStripe) {
      _renderStripe(canvas, center, r, alpha);
    } else {
      _renderSolid(canvas, center, r, alpha);
    }

    // Number circle fallback.
    if (number > 0) {
      _renderNumber(canvas, center, r);
    }

    // Edge outline (drawn without rotation for cleaner look)
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.18,
    );

    // 3D highlight (drawn without rotation so light stays fixed)
    _renderHighlight(canvas, r);
  }

  void _renderSolid(Canvas canvas, Offset center, double r, double alpha) {
    final baseColor = ballColor.withValues(alpha: alpha);

    // Main body: tighter radial gradient for more 3D pop
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.85,
          colors: [
            _lighten(baseColor, 0.25),
            _lighten(baseColor, 0.08),
            baseColor,
            _darken(baseColor, 0.25),
            _darken(baseColor, 0.5),
          ],
          stops: const [0.0, 0.25, 0.50, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    if (isCueBall) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0x22000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.15,
      );
    }
  }

  void _renderStripe(Canvas canvas, Offset center, double r, double alpha) {
    final baseColor = ballColor.withValues(alpha: alpha);

    // White base with tighter 3D gradient
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.85,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFF5F5F5),
            Color(0xFFE8E8E8),
            Color(0xFFCCCCCC),
            Color(0xFFAAAAAA),
          ],
          stops: const [0.0, 0.25, 0.50, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Color stripe band
    canvas.save();
    canvas.clipRect(
      Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.0),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.85,
          colors: [
            _lighten(baseColor, 0.3),
            _lighten(baseColor, 0.1),
            baseColor,
            _darken(baseColor, 0.2),
            _darken(baseColor, 0.45),
          ],
          stops: const [0.0, 0.25, 0.50, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.restore();

    // Thin edge ring
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _darken(baseColor, 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1,
    );
  }

  void _renderNumber(Canvas canvas, Offset center, double r) {
    final circleRadius = r * 0.42;

    if (!is8Ball) {
      canvas.drawCircle(
        center,
        circleRadius,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawCircle(
        center,
        circleRadius,
        Paint()
          ..color = const Color(0x22000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08,
      );
    }

    final textColor = is8Ball
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);
    final fontSize = number >= 10 ? r * 0.7 : r * 0.85;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _renderHighlight(Canvas canvas, double r) {
    // Primary specular highlight — bigger and brighter
    final hlCenter = Offset(-r * 0.28, -r * 0.32);
    canvas.drawCircle(
      hlCenter,
      r * 0.30,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xBBFFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCircle(center: hlCenter, radius: r * 0.30)),
    );

    // Sharp specular dot
    canvas.drawCircle(
      Offset(-r * 0.22, -r * 0.25),
      r * 0.08,
      Paint()..color = const Color(0xCCFFFFFF),
    );

    // Subtle secondary highlight
    canvas.drawCircle(
      Offset(r * 0.15, r * 0.2),
      r * 0.10,
      Paint()..color = const Color(0x15FFFFFF),
    );

    // Rim light at bottom edge (environment reflection)
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.95),
      math.pi * 0.05,
      math.pi * 0.9,
      false,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.25,
    );
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

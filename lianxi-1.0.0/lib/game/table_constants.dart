import 'package:flame/extensions.dart';

/// Standard Chinese 8-ball table dimensions (1 unit ≈ 1 cm).
/// Ref: Chinese Billiards Association competition rules: 2540 x 1270 mm,
/// with 57.15 mm balls.
class TableConstants {
  // Playing surface: 2540mm × 1270mm
  static const double length = 254.0;
  static const double width = 127.0;
  static const double halfLength = length / 2;
  static const double halfWidth = width / 2;

  // The reference table artwork has cushion noses inset from its outer wood
  // frame.  Physics, placement, and prediction must use these same noses;
  // otherwise balls appear to roll into the rail artwork before colliding.
  static const double cushionNoseHalfLength = 124.0;
  // Measured from table-reference-skin.png using the crop in Table.render.
  // The top and bottom artwork are not quite symmetric about the canvas.
  static const double cushionNoseTop = -54.5;
  static const double cushionNoseBottom = 52.0;

  // Slightly enlarged from the 2.25% regulation ratio for phone legibility.
  static const double ballRadius = 3.6;
  static const double ballDiameter = ballRadius * 2;

  // Each effective opening is narrower than two 7.2 cm balls side by side.
  static const double cornerPocketRadius = 5.0;
  static const double sidePocketRadius = 5.2;

  // Cushion rubber elasticity — ref: tailuge/billiards ee=0.85, Mathavan model
  static const double cushionRestitution = 0.78;
  static const double cushionFriction = 0.20;

  // Phenolic balls are close to elastic.  The small loss prevents repeated
  // contacts from looking perfectly lossless while keeping thin-cut transfer
  // crisp.
  static const double ballRestitution = 0.92;
  static const double ballFriction = 0.12;
  // Forge2D mixes restitution by taking the larger fixture value.
  static const double effectiveCushionRestitution = ballRestitution;

  // Head string at 1/4 table length from head rail
  static const double headStringX = -halfLength + length / 4;
  // Foot spot at 1/4 table length from foot rail
  static const double footSpotX = halfLength - length / 4;

  // Pseudo-3D Y compression
  static const double perspectiveYScale = 1.0;

  // Max impulse
  static const double maxShotPower = 9000.0;
  static const double shotSideSpinFraction = 0.08;
  static const double ballDensity = 0.35;
  static const double rollingDamping = 0.35;
  static const double slowBallSpeed = 8.0;
  static const double stopSpeed = 0.8;
  static const double ballMass =
      ballDensity * 3.141592653589793 * ballRadius * ballRadius;

  // Rail (cushion) width for visual rendering
  static const double railWidth = 10.0;

  // Centers of the visible dark holes, beyond the cushion noses.  A ball is
  // removed only after its centre actually reaches the hole.
  static final List<Vector2> pocketCenters = List.unmodifiable([
    Vector2(-127.0, -58.5),
    Vector2(0, -58.5),
    Vector2(127.0, -58.5),
    Vector2(-127.0, 56.5),
    Vector2(0, 56.5),
    Vector2(127.0, 56.5),
  ]);

  static double pocketRadiusAt(int index) {
    return (index == 1 || index == 4) ? sidePocketRadius : cornerPocketRadius;
  }
}

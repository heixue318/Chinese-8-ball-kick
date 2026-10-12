import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart';

import '../table_constants.dart';
import '../systems/trajectory_prediction.dart';
import '../systems/shot_preview_simulator.dart';
import 'ball.dart';

class Guideline extends Component {
  Guideline({required this.balls});

  final List<Ball> balls;

  bool enabled = true;
  bool showAngle = true;
  bool showObjectPath = true;
  bool showDeflection = true;
  bool showTriangle = true;
  Vector2? cueBallPosition;
  Vector2 aimDirection = Vector2(1, 0);
  Vector2 spinOffset = Vector2.zero();
  double power = 0.5;
  double cueElevationDegrees = 0;
  // The power handle returns to zero after every stroke. Zero means that no
  // stroke is being prepared, not that the player has hidden the guide.
  // Keep an ordinary-strength preview visible until the handle is pulled.
  double get previewPower => power >= 0.015 ? power : 0.5;
  String? _cachedShotKey;
  ShotPreview? _cachedShot;

  @override
  void render(Canvas canvas) {
    if (!enabled || cueBallPosition == null) return;

    final origin = cueBallPosition!;
    final objectBalls = balls
        .where(
          (b) => b.isMounted && !b.isCueBall && !b.isPocketed && b.isVisible,
        )
        .toList();
    final key = [
      origin.x,
      origin.y,
      aimDirection.x,
      aimDirection.y,
      previewPower,
      spinOffset.x,
      spinOffset.y,
      cueElevationDegrees,
      for (final ball in objectBalls) ...[
        ball.number.toDouble(),
        ball.body.position.x,
        ball.body.position.y,
      ],
    ].map((value) => value.toStringAsFixed(3)).join(',');
    if (_cachedShotKey != key) {
      _cachedShot = ShotPreviewSimulator.run(
        cuePosition: origin,
        objectPositions: {
          for (final ball in objectBalls)
            ball.number: ball.body.position.clone(),
        },
        aimDirection: aimDirection,
        power: previewPower,
        spinOffset: spinOffset,
        elevationDegrees: cueElevationDegrees,
      );
      _cachedShotKey = key;
    }
    final preview = _cachedShot!;
    final cueTrack = preview.tracks[0]!;
    if (cueTrack.length < 2) return;
    final hitIndex = objectBalls.indexWhere(
      (b) => b.number == preview.firstHit,
    );
    final approach = _pathPrediction(
      cueTrack
          .take(
            preview.firstHit == null
                ? cueTrack.length
                : preview.cueContactSample + 1,
          )
          .toList(),
      hitIndex: hitIndex < 0 ? null : hitIndex,
    );
    _drawTrajectory(canvas, approach, const Color(0xFFBDE9C9));
    final ghostCenter = preview.cueContact ?? approach.endpoint;
    _drawGhostBall(canvas, ghostCenter);
    if (hitIndex < 0 || preview.objectContact == null) return;
    final lastApproach = approach.segments.last;
    final impactDirection =
        preview.cueDirectionAtContact ??
        (lastApproach.end - lastApproach.start).normalized();

    final objectBall = objectBalls[hitIndex];
    final objectCenter = preview.objectContact!;
    final objectDir = (objectCenter - ghostCenter).normalized();
    if (objectDir.length2 < 0.001) return;
    if (showObjectPath) {
      final objectPath = _pathPrediction(preview.tracks[objectBall.number]!);
      _drawTrajectory(canvas, objectPath, const Color(0xFFFFE47B));
      if (objectPath.end == TrajectoryEnd.pocket) {
        _drawPocketHint(canvas, objectCenter, objectDir, objectPath.endpoint);
      }
      for (final ball in objectBalls) {
        if (ball == objectBall) continue;
        final track = preview.tracks[ball.number]!;
        if (track.length > 1) {
          _drawTrajectory(
            canvas,
            _pathPrediction(track),
            const Color(0xB0FFC967),
          );
        }
      }
    }

    // --- 4. Cut point on object ball surface ---
    final cutPointOnBall =
        objectCenter +
        (ghostCenter - objectCenter).normalized() * TableConstants.ballRadius;
    _drawCutPoint(canvas, cutPointOnBall);

    // --- 5. Cut angle calculation ---
    final centerLine = (objectCenter - ghostCenter).normalized();
    final cutAngle = _angleBetween(impactDirection, centerLine);
    final cutColor = _cutAngleColor(cutAngle);

    if (showAngle && cutAngle > 0.5) {
      _drawAngleArc(
        canvas,
        ghostCenter,
        impactDirection,
        centerLine,
        cutAngle,
        cutColor,
      );
    }

    // --- 5b. Right triangle from contact point T ---
    if (showTriangle && cutAngle > 3.0 && cutAngle < 85.0) {
      final contactPoint = (objectCenter + ghostCenter) * 0.5;
      _drawPocketTriangle(
        canvas,
        lastApproach.start,
        objectCenter,
        ghostCenter,
        contactPoint,
        objectDir,
        cutAngle: showAngle ? cutAngle : null,
        cutColor: cutColor,
      );
    }

    // --- 5c. Cut-point mark on object ball (standard G-vertex cut angle) ---
    if (cutAngle > 1.0) {
      _drawCutMark(canvas, objectCenter, ghostCenter);
    }

    // --- 6. Cue ball deflection path after impact ---
    if (showDeflection) {
      final postTrack = cueTrack.skip(preview.cueContactSample).toList();
      if (postTrack.length > 1) {
        final postDir = (postTrack[1] - postTrack[0]).normalized();
        final afterImpact = _pathPrediction(postTrack);
        _drawPostImpactPath(canvas, afterImpact);

        if (showAngle && cutAngle > 5.0) {
          // Separation angle: between object ball path and cue ball deflection
          final sepAngle = _angleBetween(objectDir, postDir);
          final labelPos = ghostCenter + postDir * 10;
          _drawDeflectionLabel(canvas, labelPos, sepAngle);
        }
      }
    }
  }

  TrajectoryPrediction _pathPrediction(List<Vector2> points, {int? hitIndex}) {
    final segments = <TrajectorySegment>[
      for (var i = 1; i < points.length; i++)
        TrajectorySegment(points[i - 1], points[i]),
    ];
    if (segments.isEmpty) {
      final point = points.isEmpty ? Vector2.zero() : points.first;
      segments.add(TrajectorySegment(point, point));
    }
    final endpoint = segments.last.end;
    final pocketed = TableConstants.pocketCenters.any(
      (center) =>
          (center - endpoint).length < TableConstants.cornerPocketRadius,
    );
    return TrajectoryPrediction(
      segments: segments,
      end: hitIndex != null
          ? TrajectoryEnd.ball
          : pocketed
          ? TrajectoryEnd.pocket
          : TrajectoryEnd.bankLimit,
      hitBallIndex: hitIndex,
    );
  }

  void _drawTrajectory(
    Canvas canvas,
    TrajectoryPrediction prediction,
    Color color,
  ) {
    var phase = 0.0;
    for (final segment in prediction.segments) {
      phase = _drawDottedLine(canvas, segment.start, segment.end, color, phase);
    }
  }

  void _drawGhostBall(Canvas canvas, Vector2 center) {
    final offset = Offset(center.x, center.y);
    canvas.drawCircle(
      offset,
      TableConstants.ballRadius,
      Paint()..color = const Color(0x55F4F4EA),
    );
    canvas.drawCircle(
      offset,
      TableConstants.ballRadius,
      Paint()
        ..color = const Color(0xDAFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.38,
    );
  }

  void _drawPostImpactPath(Canvas canvas, TrajectoryPrediction prediction) {
    final paint = Paint()
      ..color = const Color(0xDDF7F8F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.58
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < prediction.segments.length; i++) {
      paint.color = Color.fromARGB(
        (220 * (1 - .55 * i / prediction.segments.length)).round(),
        247,
        248,
        242,
      );
      paint.strokeWidth = i == 0 ? 0.58 : 0.43;
      final segment = prediction.segments[i];
      canvas.drawLine(
        Offset(segment.start.x, segment.start.y),
        Offset(segment.end.x, segment.end.y),
        paint,
      );
    }
  }

  double _angleBetween(Vector2 a, Vector2 b) {
    final na = a.normalized();
    final nb = b.normalized();
    if (na.length2 < 0.001 || nb.length2 < 0.001) return 0;
    final dot = na.dot(nb).clamp(-1.0, 1.0);
    return math.acos(dot) * 180 / math.pi;
  }

  void _drawCutPoint(Canvas canvas, Vector2 point) {
    // Bright dot on target ball showing where cue ball will make contact
    canvas.drawCircle(
      Offset(point.x, point.y),
      0.6,
      Paint()..color = const Color(0xFFFF5722),
    );
    canvas.drawCircle(
      Offset(point.x, point.y),
      0.6,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.2,
    );
  }

  void _drawAngleArc(
    Canvas canvas,
    Vector2 center,
    Vector2 dir1,
    Vector2 dir2,
    double angleDeg,
    Color color,
  ) {
    final angle1 = math.atan2(dir1.y, dir1.x);
    final angle2 = math.atan2(dir2.y, dir2.x);
    var sweep = angle2 - angle1;
    if (sweep > math.pi) sweep -= 2 * math.pi;
    if (sweep < -math.pi) sweep += 2 * math.pi;

    if (sweep.abs() > math.pi) {
      sweep = sweep > 0 ? sweep - 2 * math.pi : sweep + 2 * math.pi;
    }

    const arcR = 6.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.x, center.y), radius: arcR),
      angle1,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3,
    );

    // Only draw label here when triangle is NOT visible (small cut angles)
    final hasTriangle = showTriangle && angleDeg > 3.0 && angleDeg < 85.0;
    if (!hasTriangle) {
      final midAngle = angle1 + sweep / 2;
      final labelR = arcR + 4.0;
      final lx = center.x + math.cos(midAngle) * labelR;
      final ly = center.y + math.sin(midAngle) * labelR;
      _drawAngleLabel(canvas, Vector2(lx, ly), angleDeg, color);
    }
  }

  void _drawAngleLabel(Canvas canvas, Vector2 pos, double angle, Color color) {
    final label = '${angle.round()}°';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 3.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(pos.x - textPainter.width / 2, pos.y - textPainter.height / 2),
    );
  }

  void _drawDeflectionLabel(Canvas canvas, Vector2 pos, double angle) {
    final label = '分离${angle.round()}°';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0x9900BFFF),
          fontSize: 3.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(pos.x + 1.5, pos.y - 2));
  }

  /// Draw a subtle green ring when path end is near a pocket.
  void _drawPocketHint(Canvas canvas, Vector2 from, Vector2 dir, Vector2 end) {
    for (final pocket in TableConstants.pocketCenters) {
      final dist = (end - pocket).length;
      if (dist < TableConstants.cornerPocketRadius + 2) {
        canvas.drawCircle(
          Offset(pocket.x, pocket.y),
          TableConstants.cornerPocketRadius * 0.8,
          Paint()
            ..color = const Color(0x6600FF00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
        return;
      }
    }
  }

  /// Right triangle with vertex at contact point T (midpoint of G-O).
  ///
  /// T = contact point, D = foot of perpendicular from C onto the pocket line
  /// through T, C = cue ball.
  /// Triangle: T-D-C with right angle at D.
  void _drawPocketTriangle(
    Canvas canvas,
    Vector2 cueBall,
    Vector2 objectBall,
    Vector2 ghostCenter,
    Vector2 contactPoint,
    Vector2 objectDir, {
    double? cutAngle,
    Color? cutColor,
  }) {
    final lineUnit = objectDir;

    final tc = cueBall - contactPoint;
    final projLen = tc.dot(lineUnit);
    final foot = contactPoint + lineUnit * projLen;

    final perpDist = (cueBall - foot).length;
    if (perpDist < 0.5) return;

    final triPaint = Paint()
      ..color = const Color(0x44FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    canvas.drawLine(
      Offset(contactPoint.x, contactPoint.y),
      Offset(foot.x, foot.y),
      triPaint,
    );
    canvas.drawLine(
      Offset(foot.x, foot.y),
      Offset(cueBall.x, cueBall.y),
      triPaint,
    );
    canvas.drawLine(
      Offset(contactPoint.x, contactPoint.y),
      Offset(cueBall.x, cueBall.y),
      triPaint,
    );

    if (perpDist > 2.0 && projLen.abs() > 2.0) {
      final dToT = (contactPoint - foot).normalized() * 1.5;
      final dToC = (cueBall - foot).normalized() * 1.5;
      final sq1 = foot + dToT;
      final sq2 = foot + dToT + dToC;
      final sq3 = foot + dToC;
      canvas.drawLine(Offset(sq1.x, sq1.y), Offset(sq2.x, sq2.y), triPaint);
      canvas.drawLine(Offset(sq2.x, sq2.y), Offset(sq3.x, sq3.y), triPaint);
    }

    canvas.drawCircle(
      Offset(contactPoint.x, contactPoint.y),
      0.5,
      Paint()..color = const Color(0xFFFF9800),
    );

    final adjLen = projLen.abs();
    final hypLen = tc.length;
    if (perpDist < 0.1) return;

    final hypRatio = hypLen / perpDist;
    final adjRatio = adjLen / perpDist;

    final midAdj = (contactPoint + foot) * 0.5;
    final midPerp = (foot + cueBall) * 0.5;
    final midHyp = (contactPoint + cueBall) * 0.5;

    _drawTriLabel(
      canvas,
      midAdj,
      '长${adjRatio.toStringAsFixed(1)}',
      const Color(0xBBFFEB3B),
    );
    _drawTriLabel(canvas, midPerp, '短1.0', const Color(0xBB00BFFF));
    _drawTriLabel(
      canvas,
      midHyp,
      '斜${hypRatio.toStringAsFixed(1)}',
      const Color(0xBB66BB6A),
    );

    // Cut angle label inside the triangle (centroid area)
    if (cutAngle != null && cutAngle > 0.5) {
      final centroid = (contactPoint + foot + cueBall) / 3.0;
      _drawAngleLabel(
        canvas,
        centroid,
        cutAngle,
        cutColor ?? const Color(0xFFFFEB3B),
      );
    }
  }

  /// Draw the "cut mark" on the target ball surface.
  /// The cut mark is where the aim line (from cue ball through ghost center G)
  /// intersects the object ball's circumference — i.e. the chord endpoints
  /// perpendicular to G→O through the contact point T.
  void _drawCutMark(Canvas canvas, Vector2 objectCenter, Vector2 ghostCenter) {
    final goDir = (objectCenter - ghostCenter);
    if (goDir.length < 0.001) return;
    final goUnit = goDir.normalized();
    // Perpendicular to G→O
    final perpUnit = Vector2(-goUnit.y, goUnit.x);

    final contactPoint = (objectCenter + ghostCenter) * 0.5;
    final r = TableConstants.ballRadius;

    // Find chord endpoints: line through T perpendicular to G→O intersected with ball circle
    final tc = contactPoint - objectCenter;
    final b = 2 * tc.dot(perpUnit);
    final c = tc.dot(tc) - r * r;
    final disc = b * b - 4 * c;
    if (disc < 0) return;

    final sqrtD = math.sqrt(disc);
    final s1 = (-b - sqrtD) / 2;
    final s2 = (-b + sqrtD) / 2;
    final p1 = contactPoint + perpUnit * s1;
    final p2 = contactPoint + perpUnit * s2;

    // Draw cut chord on ball
    final cutPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..strokeWidth = 0.4;
    canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), cutPaint);

    // Highlight chord endpoints
    final dotPaint = Paint()..color = const Color(0xFFE91E63);
    canvas.drawCircle(Offset(p1.x, p1.y), 0.35, dotPaint);
    canvas.drawCircle(Offset(p2.x, p2.y), 0.35, dotPaint);
  }

  void _drawTriLabel(Canvas canvas, Vector2 pos, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 2.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(pos.x + 0.5, pos.y - 1.5));
  }

  Color _cutAngleColor(double degrees) {
    if (degrees <= 20) return const Color(0xFF66BB6A);
    if (degrees <= 45) return const Color(0xFFFFEB3B);
    return const Color(0xFFE53935);
  }

  double _drawDottedLine(
    Canvas canvas,
    Vector2 from,
    Vector2 to,
    Color color,
    double phase,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.48
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dash = 2.4;
    const gap = 1.6;
    final delta = to - from;
    final len = delta.length;
    if (len < 0.01) return phase;
    final step = delta / len;
    var traveled = 0.0;
    while (traveled < len) {
      final inDash = phase < dash;
      final remaining = (inDash ? dash : dash + gap) - phase;
      final next = math.min(len, traveled + remaining);
      if (inDash) {
        canvas.drawLine(
          Offset(from.x + step.x * traveled, from.y + step.y * traveled),
          Offset(from.x + step.x * next, from.y + step.y * next),
          paint,
        );
      }
      phase = (phase + next - traveled) % (dash + gap);
      traveled = next;
    }
    return phase;
  }
}

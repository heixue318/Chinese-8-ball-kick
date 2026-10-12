import 'dart:math' as math;

import 'package:flame/extensions.dart';

import '../table_constants.dart';

enum TrajectoryEnd { pocket, ball, bankLimit }

class TrajectorySegment {
  const TrajectorySegment(this.start, this.end);
  final Vector2 start;
  final Vector2 end;
}

class TrajectoryPrediction {
  const TrajectoryPrediction({
    required this.segments,
    required this.end,
    this.hitBallIndex,
  });

  final List<TrajectorySegment> segments;
  final TrajectoryEnd end;
  final int? hitBallIndex;
  Vector2 get endpoint => segments.last.end;
}

/// Geometric preview: reflections and collisions, not a full spin simulation.
class TrajectoryPredictor {
  const TrajectoryPredictor._();

  static TrajectoryPrediction trace({
    required Vector2 origin,
    required Vector2 direction,
    List<Vector2> obstacleCenters = const [],
    int maxBanks = 5,
    double? initialSpeed,
    double angularSpeed = 0,
  }) {
    var point = origin.clone();
    var ray = direction.normalized();
    var speed = initialSpeed;
    final segments = <TrajectorySegment>[];
    final minX =
        -TableConstants.cushionNoseHalfLength + TableConstants.ballRadius;
    final maxX =
        TableConstants.cushionNoseHalfLength - TableConstants.ballRadius;
    final minY = TableConstants.cushionNoseTop + TableConstants.ballRadius;
    final maxY = TableConstants.cushionNoseBottom - TableConstants.ballRadius;

    for (var bank = 0; bank <= maxBanks; bank++) {
      var tx = double.infinity;
      var ty = double.infinity;
      if (ray.x > 1e-6) tx = (maxX - point.x) / ray.x;
      if (ray.x < -1e-6) tx = (minX - point.x) / ray.x;
      if (ray.y > 1e-6) ty = (maxY - point.y) / ray.y;
      if (ray.y < -1e-6) ty = (minY - point.y) / ray.y;
      final bankDistance = math.min(tx, ty);
      if (!bankDistance.isFinite || bankDistance < 0) break;

      // Linear damping in Forge2D gives dv/distance = -damping.  End the
      // preview where the ball's visible run ends instead of drawing an
      // impossible fixed number of banks for a gentle stroke.
      final travelBudget = speed == null
          ? double.infinity
          : math.max(
              0.0,
              (speed - TableConstants.slowBallSpeed) /
                  TableConstants.rollingDamping,
            );
      final availableDistance = math.min(bankDistance, travelBudget);

      final collision = _nearestBall(
        point,
        ray,
        obstacleCenters,
        availableDistance,
      );
      if (collision != null) {
        final end = point + ray * collision.$2;
        segments.add(TrajectorySegment(point.clone(), end));
        return TrajectoryPrediction(
          segments: segments,
          end: TrajectoryEnd.ball,
          hitBallIndex: collision.$1,
        );
      }

      if (travelBudget <= bankDistance) {
        segments.add(
          TrajectorySegment(point.clone(), point + ray * travelBudget),
        );
        return TrajectoryPrediction(
          segments: segments,
          end: TrajectoryEnd.bankLimit,
        );
      }

      final end = point + ray * bankDistance;
      segments.add(TrajectorySegment(point.clone(), end));
      final pocket = _pocketAtBoundary(end);
      if (pocket != null) {
        segments[segments.length - 1] = TrajectorySegment(
          point.clone(),
          pocket,
        );
        return TrajectoryPrediction(
          segments: segments,
          end: TrajectoryEnd.pocket,
        );
      }
      if (bank == maxBanks) {
        return TrajectoryPrediction(
          segments: segments,
          end: TrajectoryEnd.bankLimit,
        );
      }

      final atVertical = (tx - bankDistance).abs() < 1e-5;
      final atHorizontal = (ty - bankDistance).abs() < 1e-5;
      if (speed != null) {
        final incomingSpeed = speed;
        speed = math.max(
          0.0,
          speed - TableConstants.rollingDamping * bankDistance,
        );
        final elapsed =
            bankDistance / math.max(1.0, (incomingSpeed + speed) * .5);
        angularSpeed *= math.exp(-.3 * elapsed);
        var velocity = ray * speed;
        if (atVertical) {
          final bounce = _bounce(
            velocity,
            Vector2(ray.x > 0 ? -1 : 1, 0),
            angularSpeed,
          );
          velocity = bounce.$1;
          angularSpeed = bounce.$2;
        }
        if (atHorizontal) {
          final bounce = _bounce(
            velocity,
            Vector2(0, ray.y > 0 ? -1 : 1),
            angularSpeed,
          );
          velocity = bounce.$1;
          angularSpeed = bounce.$2;
        }
        speed = velocity.length;
        ray = velocity.normalized();
      } else {
        if (atVertical) ray.x *= -TableConstants.effectiveCushionRestitution;
        if (atHorizontal) ray.y *= -TableConstants.effectiveCushionRestitution;
        ray.normalize();
      }
      point = end + ray * 0.001;
    }

    return TrajectoryPrediction(
      segments: segments.isEmpty
          ? [TrajectorySegment(origin.clone(), origin.clone())]
          : segments,
      end: TrajectoryEnd.bankLimit,
    );
  }

  static (Vector2, double) _bounce(
    Vector2 velocity,
    Vector2 inwardNormal,
    double angularSpeed,
  ) {
    final normalSpeed = velocity.dot(inwardNormal);
    if (normalSpeed >= 0) return (velocity, angularSpeed);
    final restitution = TableConstants.effectiveCushionRestitution;
    final tangent = Vector2(-inwardNormal.y, inwardNormal.x);
    final reflected =
        velocity - inwardNormal * ((1 + restitution) * normalSpeed);
    // Circle inertia is 1/2 m r². Match the rail's tangential friction impulse.
    final slip =
        velocity.dot(tangent) - angularSpeed * TableConstants.ballRadius;
    final friction = math.sqrt(
      TableConstants.ballFriction * TableConstants.cushionFriction,
    );
    final maximum = friction * (1 + restitution) * normalSpeed.abs();
    final tangentialChange = (-slip / 3).clamp(-maximum, maximum);
    reflected.add(tangent * tangentialChange);
    return (
      reflected,
      angularSpeed - 2 * tangentialChange / TableConstants.ballRadius,
    );
  }

  static (int, double)? _nearestBall(
    Vector2 point,
    Vector2 ray,
    List<Vector2> obstacles,
    double maximum,
  ) {
    var nearest = maximum;
    int? index;
    final collisionRadius = TableConstants.ballDiameter;
    for (var i = 0; i < obstacles.length; i++) {
      final offset = point - obstacles[i];
      final b = 2 * offset.dot(ray);
      final c = offset.dot(offset) - collisionRadius * collisionRadius;
      final discriminant = b * b - 4 * c;
      if (discriminant < 0) continue;
      final t = (-b - math.sqrt(discriminant)) / 2;
      if (t > 0.05 && t < nearest) {
        nearest = t;
        index = i;
      }
    }
    return index == null ? null : (index, nearest);
  }

  static Vector2? _pocketAtBoundary(Vector2 end) {
    const sideOpening = 4.2;
    const cornerOpening = 4.7;
    final nearTop =
        (end.y - TableConstants.cushionNoseTop - TableConstants.ballRadius)
            .abs() <
        .01;
    final nearBottom =
        (end.y - TableConstants.cushionNoseBottom + TableConstants.ballRadius)
            .abs() <
        .01;
    final nearLeft =
        (end.x +
                TableConstants.cushionNoseHalfLength -
                TableConstants.ballRadius)
            .abs() <
        .01;
    final nearRight =
        (end.x -
                TableConstants.cushionNoseHalfLength +
                TableConstants.ballRadius)
            .abs() <
        .01;
    if (nearTop || nearBottom) {
      final row = nearTop ? 0 : 3;
      if (end.x.abs() < sideOpening) {
        return TableConstants.pocketCenters[row + 1];
      }
      if (end.x < -TableConstants.cushionNoseHalfLength + cornerOpening) {
        return TableConstants.pocketCenters[row];
      }
      if (end.x > TableConstants.cushionNoseHalfLength - cornerOpening) {
        return TableConstants.pocketCenters[row + 2];
      }
    }
    if (nearLeft || nearRight) {
      final column = nearLeft ? 0 : 2;
      if (end.y < TableConstants.cushionNoseTop + cornerOpening) {
        return TableConstants.pocketCenters[column];
      }
      if (end.y > TableConstants.cushionNoseBottom - cornerOpening) {
        return TableConstants.pocketCenters[3 + column];
      }
    }
    return null;
  }
}

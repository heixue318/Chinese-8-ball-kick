import 'dart:math' as math;

import 'package:flame/extensions.dart';
import 'package:forge2d/forge2d.dart' as physics;

import '../table_constants.dart';
import 'table_geometry.dart';

class ShotPreview {
  const ShotPreview({
    required this.tracks,
    this.firstHit,
    this.cueContact,
    this.objectContact,
    this.cueDirectionAtContact,
    this.cueContactSample = 0,
  });

  final Map<int, List<Vector2>> tracks;
  final int? firstHit;
  final Vector2? cueContact;
  final Vector2? objectContact;
  final Vector2? cueDirectionAtContact;
  final int cueContactSample;
}

/// Runs a disposable copy of the same Forge2D bodies and rubber geometry as
/// live play. The dashed lines are samples of this world, not ray reflections.
class ShotPreviewSimulator {
  const ShotPreviewSimulator._();

  static ShotPreview run({
    required Vector2 cuePosition,
    required Map<int, Vector2> objectPositions,
    required Vector2 aimDirection,
    required double power,
    required Vector2 spinOffset,
    required double elevationDegrees,
  }) {
    const dt = 1 / 60;
    final world = physics.World(Vector2.zero());
    for (final (start, end) in TableGeometry.cushionSegments()) {
      world
          .createBody(physics.BodyDef(type: physics.BodyType.static))
          .createFixture(
            physics.FixtureDef(physics.EdgeShape()..set(start, end))
              ..restitution = TableConstants.cushionRestitution
              ..friction = TableConstants.cushionFriction,
          );
    }

    physics.Body makeBall(int number, Vector2 position) {
      final body = world.createBody(
        physics.BodyDef()
          ..type = physics.BodyType.dynamic
          ..position = position.clone()
          ..linearDamping = TableConstants.rollingDamping
          ..angularDamping = .3
          ..bullet = true,
      );
      body.createFixture(
        physics.FixtureDef(
            physics.CircleShape()..radius = TableConstants.ballRadius,
          )
          ..density = TableConstants.ballDensity
          ..restitution = TableConstants.ballRestitution
          ..friction = TableConstants.ballFriction
          ..userData = number,
      );
      return body;
    }

    final bodies = <int, physics.Body>{0: makeBall(0, cuePosition)};
    for (final entry in objectPositions.entries) {
      bodies[entry.key] = makeBall(entry.key, entry.value);
    }
    final tracks = <int, List<Vector2>>{
      for (final entry in bodies.entries)
        entry.key: [entry.value.position.clone()],
    };
    final contacts = _PreviewContactListener(
      bodies,
      tracks,
      power,
      spinOffset.y,
    );
    world.setContactListener(contacts);

    final direction = aimDirection.normalized();
    final efficiency = math
        .pow(math.cos(elevationDegrees * math.pi / 180), 2)
        .toDouble()
        .clamp(.12, 1.0);
    final impulse = power * TableConstants.maxShotPower * efficiency;
    final cue = bodies[0]!;
    cue.applyLinearImpulse(direction * impulse);
    cue.applyLinearImpulse(
      Vector2(-direction.y, direction.x) *
          spinOffset.x *
          impulse *
          TableConstants.shotSideSpinFraction,
    );
    cue.angularVelocity = spinOffset.x * 12 * efficiency;

    final previous = <int, Vector2>{
      for (final entry in bodies.entries)
        entry.key: entry.value.position.clone(),
    };
    var quietFrames = 0;
    for (var frame = 0; frame < 900; frame++) {
      world.stepDt(dt);
      var moving = false;
      for (final entry in bodies.entries) {
        final number = entry.key;
        final body = entry.value;
        if (!body.isActive) continue;
        _enforceBounds(body);
        final last = previous[number]!;
        final pocket = _capturedPocket(body.position, last);
        if (pocket != null) {
          tracks[number]!.add(body.position.clone());
          body.linearVelocity = Vector2.zero();
          body.angularVelocity = 0;
          body.setActive(false);
          continue;
        }
        _applyPocketPull(body);
        final speed = body.linearVelocity.length;
        if (speed > 0 && speed < TableConstants.slowBallSpeed) {
          body.linearVelocity.scale(math.exp(-9 * dt));
        }
        if (body.linearVelocity.length < TableConstants.stopSpeed) {
          body.linearVelocity = Vector2.zero();
          body.angularVelocity = 0;
        } else {
          moving = true;
        }
        if ((body.position - tracks[number]!.last).length >= 1.2 ||
            (body.linearVelocity.length == 0 &&
                (body.position - tracks[number]!.last).length > .01)) {
          tracks[number]!.add(body.position.clone());
        }
        previous[number] = body.position.clone();
      }
      quietFrames = moving ? 0 : quietFrames + 1;
      if (quietFrames >= 2) break;
    }
    return ShotPreview(
      tracks: tracks,
      firstHit: contacts.firstHit,
      cueContact: contacts.cueContact,
      objectContact: contacts.objectContact,
      cueDirectionAtContact: contacts.cueDirectionAtContact,
      cueContactSample: contacts.cueContactSample,
    );
  }

  static void _enforceBounds(physics.Body body) {
    final p = body.position;
    for (var i = 0; i < TableConstants.pocketCenters.length; i++) {
      final mouth =
          TableConstants.pocketRadiusAt(i) + TableConstants.ballRadius * 1.8;
      if ((p - TableConstants.pocketCenters[i]).length < mouth) return;
    }
    final minX =
        -TableConstants.cushionNoseHalfLength + TableConstants.ballRadius;
    final maxX =
        TableConstants.cushionNoseHalfLength - TableConstants.ballRadius;
    final minY = TableConstants.cushionNoseTop + TableConstants.ballRadius;
    final maxY = TableConstants.cushionNoseBottom - TableConstants.ballRadius;
    final outsideX = p.x < minX || p.x > maxX;
    final outsideY = p.y < minY || p.y > maxY;
    if (!outsideX && !outsideY) return;
    final velocity = body.linearVelocity.clone();
    if (outsideX &&
        ((p.x < minX && velocity.x < 0) || (p.x > maxX && velocity.x > 0))) {
      velocity.x *= -TableConstants.effectiveCushionRestitution;
    }
    if (outsideY &&
        ((p.y < minY && velocity.y < 0) || (p.y > maxY && velocity.y > 0))) {
      velocity.y *= -TableConstants.effectiveCushionRestitution;
    }
    body.setTransform(
      Vector2(p.x.clamp(minX, maxX), p.y.clamp(minY, maxY)),
      body.angle,
    );
    body.linearVelocity = velocity;
  }

  static Vector2? _capturedPocket(Vector2 current, Vector2 previous) {
    for (var i = 0; i < TableConstants.pocketCenters.length; i++) {
      final center = TableConstants.pocketCenters[i];
      final radius = TableConstants.pocketRadiusAt(i) * .6;
      final travel = current - previous;
      final t = travel.length2 > .0001
          ? ((center - previous).dot(travel) / travel.length2).clamp(0.0, 1.0)
          : 1.0;
      if ((current - center).length < radius ||
          (previous + travel * t - center).length < radius) {
        return center;
      }
    }
    return null;
  }

  static void _applyPocketPull(physics.Body body) {
    var distance = double.infinity;
    var index = -1;
    for (var i = 0; i < TableConstants.pocketCenters.length; i++) {
      final d = (body.position - TableConstants.pocketCenters[i]).length;
      if (d < distance) {
        distance = d;
        index = i;
      }
    }
    if (index < 0) return;
    final zone = TableConstants.pocketRadiusAt(index) * 1.4;
    if (distance < zone && body.linearVelocity.length < 120 && distance > .01) {
      final toward = (TableConstants.pocketCenters[index] - body.position)
          .normalized();
      body.applyForce(toward * ((1 - distance / zone) * 1200));
    }
  }
}

class _PreviewContactListener extends physics.ContactListener {
  _PreviewContactListener(
    this.bodies,
    this.tracks,
    this.power,
    this.verticalSpin,
  );

  final Map<int, physics.Body> bodies;
  final Map<int, List<Vector2>> tracks;
  final double power;
  final double verticalSpin;
  int? firstHit;
  Vector2? cueContact;
  Vector2? objectContact;
  Vector2? cueDirectionAtContact;
  int cueContactSample = 0;

  @override
  void beginContact(physics.Contact contact) {
    final a = contact.fixtureA.userData;
    final b = contact.fixtureB.userData;
    if (a is! int || b is! int || a == b || (a != 0 && b != 0)) return;
    if (firstHit != null) return;
    firstHit = a == 0 ? b : a;
    final cue = bodies[0]!;
    final object = bodies[firstHit]!;
    cueContact = cue.position.clone();
    objectContact = object.position.clone();
    cueDirectionAtContact = cue.linearVelocity.normalized();
    tracks[0]!.add(cueContact!.clone());
    cueContactSample = tracks[0]!.length - 1;
    if (verticalSpin.abs() >= .02) {
      final axis = (object.position - cue.position).normalized();
      cue.applyLinearImpulse(
        axis * (-verticalSpin * power * TableConstants.maxShotPower * .055),
      );
    }
  }
}

import 'package:cr_billiards/game/systems/trajectory_prediction.dart';
import 'package:cr_billiards/game/table_constants.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' as physics;

void main() {
  for (final spin in [0.0, 12.0, -12.0]) {
    test('first-bank prediction follows Forge2D with spin $spin', () {
      final world = physics.World(Vector2.zero());
      final rail = world.createBody(
        physics.BodyDef(type: physics.BodyType.static),
      );
      rail.createFixture(
        physics.FixtureDef(
            physics.EdgeShape()..set(
              Vector2(-100, TableConstants.cushionNoseBottom),
              Vector2(100, TableConstants.cushionNoseBottom),
            ),
          )
          ..restitution = TableConstants.cushionRestitution
          ..friction = TableConstants.cushionFriction,
      );
      final ball = world.createBody(
        physics.BodyDef()
          ..type = physics.BodyType.dynamic
          ..position = Vector2.zero()
          ..linearVelocity = Vector2(50, 100)
          ..angularVelocity = spin
          ..linearDamping = TableConstants.rollingDamping
          ..angularDamping = .3
          ..bullet = true,
      );
      ball.createFixture(
        physics.FixtureDef(
            physics.CircleShape()..radius = TableConstants.ballRadius,
          )
          ..density = TableConstants.ballDensity
          ..restitution = TableConstants.ballRestitution
          ..friction = TableConstants.ballFriction,
      );

      final path = TrajectoryPredictor.trace(
        origin: Vector2.zero(),
        direction: Vector2(50, 100),
        initialSpeed: Vector2(50, 100).length,
        angularSpeed: spin,
        maxBanks: 1,
      );
      expect(path.segments, hasLength(2));
      final expected = (path.segments[1].end - path.segments[1].start)
          .normalized();

      for (var i = 0; i < 120 && ball.linearVelocity.y >= 0; i++) {
        world.stepDt(1 / 120);
      }
      expect(ball.linearVelocity.y, lessThan(0));
      final actual = ball.linearVelocity.normalized();
      expect(actual.x, closeTo(expected.x, .04));
      expect(actual.y, closeTo(expected.y, .04));
    });
  }
}

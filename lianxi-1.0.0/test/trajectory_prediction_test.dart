import 'package:cr_billiards/game/systems/trajectory_prediction.dart';
import 'package:cr_billiards/game/table_constants.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unobstructed line reflects through five cushions', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(1, 0),
    );
    expect(path.end, TrajectoryEnd.bankLimit);
    expect(path.segments, hasLength(6));
    expect(
      path.segments.first.end.x,
      closeTo(
        TableConstants.cushionNoseHalfLength - TableConstants.ballRadius,
        .01,
      ),
    );
  });

  test('a high-power cue preview can include a sixth cushion', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(1, 0),
      maxBanks: 6,
    );
    expect(path.end, TrajectoryEnd.bankLimit);
    expect(path.segments, hasLength(7));
  });

  test('bank direction uses the same restitution as the real cushion', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(1, .25),
      maxBanks: 1,
    );
    final afterBank = path.segments[1].end - path.segments[1].start;
    expect(
      afterBank.y / -afterBank.x,
      closeTo(.25 / TableConstants.effectiveCushionRestitution, .001),
    );
  });

  test('a vertical line into the pocket ends at the visible hole centre', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(0, 1),
      maxBanks: 0,
    );
    expect(path.endpoint.y, closeTo(TableConstants.pocketCenters[4].y, .01));
  });

  test('a line ends at the middle pocket instead of reflecting', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(0, -1),
    );
    expect(path.end, TrajectoryEnd.pocket);
    expect(path.segments, hasLength(1));
  });

  test('a line stops at the ghost-ball centre before an object ball', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(1, 0),
      obstacleCenters: [Vector2(50, 0)],
    );
    expect(path.end, TrajectoryEnd.ball);
    expect(path.hitBallIndex, 0);
    expect(path.endpoint.x, closeTo(50 - TableConstants.ballDiameter, .01));
  });

  test('a soft shot stops before the first cushion', () {
    final path = TrajectoryPredictor.trace(
      origin: Vector2.zero(),
      direction: Vector2(1, 0),
      initialSpeed: 35,
    );
    expect(path.end, TrajectoryEnd.bankLimit);
    expect(
      path.endpoint.x,
      closeTo(
        (35 - TableConstants.slowBallSpeed) / TableConstants.rollingDamping,
        .01,
      ),
    );
  });
}

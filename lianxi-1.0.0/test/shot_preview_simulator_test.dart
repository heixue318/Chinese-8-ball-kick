import 'package:cr_billiards/game/systems/shot_preview_simulator.dart';
import 'package:cr_billiards/game/components/guideline.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guide stays visible when the power handle resets after a shot', () {
    final guide = Guideline(balls: [])..power = 0;
    expect(guide.previewPower, .5);
    final preview = ShotPreviewSimulator.run(
      cuePosition: Vector2(-40, 0),
      objectPositions: const {},
      aimDirection: Vector2(1, 0),
      power: guide.previewPower,
      spinOffset: Vector2.zero(),
      elevationDegrees: 0,
    );
    expect(preview.tracks[0]!.length, greaterThan(1));

    guide.power = .25;
    expect(guide.previewPower, .25);
  });

  test('preview uses ball contact from the same physics world', () {
    final preview = ShotPreviewSimulator.run(
      cuePosition: Vector2(-40, 0),
      objectPositions: {1: Vector2(20, 0)},
      aimDirection: Vector2(1, 0),
      power: .35,
      spinOffset: Vector2.zero(),
      elevationDegrees: 0,
    );
    expect(preview.firstHit, 1);
    expect(preview.cueContact, isNotNull);
    expect(preview.cueContact!.x, closeTo(20 - 7.2, 1.0));
    expect(preview.tracks[1]!.length, greaterThan(2));
  });

  test('side spin changes the predicted bank path', () {
    ShotPreview run(double spin) => ShotPreviewSimulator.run(
      cuePosition: Vector2(0, 0),
      objectPositions: const {},
      aimDirection: Vector2(1, .55),
      power: .4,
      spinOffset: Vector2(spin, 0),
      elevationDegrees: 0,
    );
    final left = run(-.8).tracks[0]!;
    final right = run(.8).tracks[0]!;
    expect(left.length, greaterThan(2));
    expect(right.length, greaterThan(2));
    expect((left.last - right.last).length, greaterThan(5));
  });
}

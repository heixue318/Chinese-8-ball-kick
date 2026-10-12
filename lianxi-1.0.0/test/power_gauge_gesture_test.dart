import 'package:cr_billiards/ui/practice_input.dart';
import 'package:flame/extensions.dart';
import 'package:cr_billiards/game/input/power_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cr_billiards/ui/widgets/practice_controls.dart';

class _InputGame implements PracticeInput {
  @override
  final ValueNotifier<Vector2> spinNotifier = ValueNotifier<Vector2>(
    Vector2.zero(),
  );
  @override
  Vector2 aimDirection = Vector2(1, 0);
  @override
  void setAimDirection(Vector2 value) => aimDirection = value;
  @override
  void setSpinOffset(Vector2 value) => spinNotifier.value = value;
  double selectedPower = 0;
  int shots = 0;
  bool aiming = true;
  @override
  bool get canAim => aiming;
  @override
  void setPower(double value) => selectedPower = value;
  @override
  Future<void> shoot() async {
    shots++;
  }
}

Future<Offset> _mount(WidgetTester tester, _InputGame game) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 70,
            height: 320,
            child: PowerGauge(game: game),
          ),
        ),
      ),
    ),
  );
  return tester.getTopLeft(find.byType(PowerGauge)) + const Offset(35, 20);
}

void main() {
  testWidgets('engine independent practice controls render', (tester) async {
    final game = _InputGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF333433),
          body: Center(
            child: RepaintBoundary(
              key: const Key('controls'),
              child: SizedBox(
                width: 420,
                height: 360,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 320,
                      child: PowerGauge(game: game),
                    ),
                    SizedBox(
                      width: 60,
                      height: 320,
                      child: FineAimWheel(game: game),
                    ),
                    SpinControl(game: game),
                    CueAngleControl(
                      angle: 25,
                      enabled: true,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('controls')),
      matchesGoldenFile('goldens/practice-input-controls.png'),
    );
    await tester.drag(find.byType(FineAimWheel), const Offset(0, 30));
    expect(game.aimDirection.y, greaterThan(0));
    game.aiming = false;
    final previous = game.aimDirection.clone();
    await tester.drag(find.byType(FineAimWheel), const Offset(0, 30));
    expect(game.aimDirection, previous);
  });
  testWidgets('returning to zero before release cancels the shot', (
    tester,
  ) async {
    final game = _InputGame();
    final start = await _mount(tester, game);
    final drag = await tester.startGesture(start);
    await drag.moveTo(start + const Offset(0, 150));
    await tester.pump();
    expect(game.selectedPower, greaterThan(.4));
    await drag.moveTo(start);
    await drag.up();
    await tester.pump();
    expect(game.selectedPower, 0);
    expect(game.shots, 0);
  });

  testWidgets('release with power shoots once and resets the handle', (
    tester,
  ) async {
    final game = _InputGame();
    final start = await _mount(tester, game);
    final drag = await tester.startGesture(start);
    await drag.moveTo(start + const Offset(0, 130));
    await drag.up();
    await tester.pump();
    expect(game.shots, 1);
    expect(game.selectedPower, 0);
  });

  testWidgets('cancelled touch and disabled aiming never shoot', (
    tester,
  ) async {
    final game = _InputGame();
    final start = await _mount(tester, game);
    final drag = await tester.startGesture(start);
    await drag.moveTo(start + const Offset(0, 130));
    await drag.cancel();
    await tester.pump();
    expect(game.shots, 0);
    expect(game.selectedPower, 0);
    game.aiming = false;
    await tester.dragFrom(start, const Offset(0, 130));
    await tester.pump();
    expect(game.shots, 0);
  });
}

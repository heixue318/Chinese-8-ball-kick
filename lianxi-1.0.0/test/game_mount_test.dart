import 'package:cr_billiards/game/billiards_game.dart';
import 'package:cr_billiards/game/components/ball.dart';
import 'package:cr_billiards/main.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('standard opening renders without a startup exception', (
    tester,
  ) async {
    await tester.pumpWidget(const BilliardsApp());
    await tester.tap(find.text('标准开局'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  test('standard rack update waits for ball bodies to mount', () {
    final game = BilliardsGame(gameMode: GameMode.standard);
    game.balls.add(Ball(number: 1, position: Vector2.zero()));
    game.state = GameState.placingBall;

    expect(() => game.update(1 / 60), returnsNormally);
  });
}

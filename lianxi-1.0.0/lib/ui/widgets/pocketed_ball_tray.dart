import 'package:flutter/material.dart';

/// The practice table's compact ball-return channel.
class PocketedBallTray extends StatelessWidget {
  const PocketedBallTray({super.key, required this.balls});

  final List<int> balls;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final diameter = (bounds.maxHeight - 10).clamp(18.0, 26.0);
        final visibleBalls = balls.length > 5
            ? balls.sublist(balls.length - 5)
            : balls;
        final pitch = visibleBalls.length <= 1
            ? 0.0
            : ((bounds.maxWidth - 78 - diameter) / (visibleBalls.length - 1))
                  .clamp(14.0, diameter + 3);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(bounds.maxHeight / 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5F6361),
                Color(0xFF151A1B),
                Color(0xFF090D0E),
                Color(0xFF3C4140),
              ],
              stops: [0, .17, .78, 1],
            ),
            border: Border.all(color: const Color(0xFF81837B), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                width: 62,
                child: Center(
                  child: Text(
                    '进球收集',
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFFE7E8DD),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 69,
                top: 3,
                bottom: 3,
                width: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: const Color(0xFF050809),
                  ),
                ),
              ),
              ...visibleBalls.asMap().entries.map((entry) {
                final target = 78.0 + entry.key * pitch;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(entry.value),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, child) => Positioned(
                    left: 78 + (target - 78) * progress,
                    top: (bounds.maxHeight - diameter) / 2,
                    width: diameter,
                    height: diameter,
                    child: Opacity(
                      opacity: (.35 + .65 * progress),
                      child: child,
                    ),
                  ),
                  child: PocketBallIcon(number: entry.value),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class PocketBallIcon extends StatelessWidget {
  const PocketBallIcon({
    super.key,
    required this.number,
    this.question = false,
  });
  final int number;
  final bool question;

  static const colors = <int, Color>{
    1: Color(0xFFE7C934),
    2: Color(0xFF2456B8),
    3: Color(0xFFC93A32),
    4: Color(0xFF68389A),
    5: Color(0xFFE3892D),
    6: Color(0xFF2B8A54),
    7: Color(0xFF8D2B37),
    8: Color(0xFF111316),
    9: Color(0xFFE7C934),
    10: Color(0xFF2456B8),
    11: Color(0xFFC93A32),
    12: Color(0xFF68389A),
    13: Color(0xFFE3892D),
    14: Color(0xFF2B8A54),
    15: Color(0xFF8D2B37),
  };

  @override
  Widget build(BuildContext context) {
    final color = question
        ? const Color(0xFF7B8585)
        : (colors[number] ?? Colors.grey);
    final stripe = number >= 9 && !question;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.42, -.45),
          radius: .95,
          colors: [
            Color.lerp(color, Colors.white, .55)!,
            color,
            Color.lerp(color, Colors.black, .55)!,
          ],
          stops: const [0, .45, 1],
        ),
        border: Border.all(color: const Color(0xFF111416), width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: stripe ? 19 : 15,
          height: stripe ? 16 : 15,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F1DA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            question ? '?' : '$number',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF232424),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class BallGroupIndicator extends StatelessWidget {
  const BallGroupIndicator({super.key, required this.pocketedBalls});
  final List<int> pocketedBalls;

  @override
  Widget build(BuildContext context) {
    final firstGroupBall = pocketedBalls.where((n) => n != 8).firstOrNull;
    final unknown = firstGroupBall == null;
    final stripes = !unknown && firstGroupBall >= 9;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF151B1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF64716D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: PocketBallIcon(
              number: unknown
                  ? 0
                  : stripes
                  ? 10
                  : 2,
              question: unknown,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            unknown
                ? '待分球'
                : stripes
                ? '花色球'
                : '全色球',
            style: const TextStyle(
              color: Color(0xFFE8E8DD),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

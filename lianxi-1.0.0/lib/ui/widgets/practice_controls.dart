import 'dart:math' as math;
import 'skin_asset.dart';
import 'package:flame/extensions.dart' show Vector2;
import 'package:flutter/material.dart';
import '../practice_input.dart';

const controlGold = Color(0xFFD2B57B);
const controlInk = Color(0xFF141D1B);

class FineAimWheel extends StatefulWidget {
  const FineAimWheel({super.key, required this.game});
  final PracticeInput game;
  @override
  State<FineAimWheel> createState() => _FineAimWheelState();
}

class _FineAimWheelState extends State<FineAimWheel> {
  double _travel = 0;
  void _adjust(double pixels) {
    if (!widget.game.canAim) return;
    final direction = widget.game.aimDirection;
    final angle = math.atan2(direction.y, direction.x) + pixels * .0014;
    widget.game.setAimDirection(Vector2(math.cos(angle), math.sin(angle)));
    setState(() => _travel += pixels);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '瞄准微调',
    onIncrease: () => _adjust(1),
    onDecrease: () => _adjust(-1),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => _adjust(details.delta.dy),
      child: SkinAsset(
        'aim-wheel.png',
        const Rect.fromLTWH(390, 0, 244, 1536),
        wheelOffset: _travel,
      ),
    ),
  );
}

class SpinControl extends StatelessWidget {
  const SpinControl({super.key, required this.game});
  final PracticeInput game;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Vector2>(
    valueListenable: game.spinNotifier,
    builder: (context, spin, _) => _ControlTile(
      label: '母球加塞',
      onTap: game.canAim ? () => _open(context) : null,
      child: SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          children: [
            const Positioned.fill(
              child: SkinAsset('ball-0.png', Rect.fromLTWH(155, 155, 943, 950)),
            ),
            Positioned(
              left: 27 + spin.x * 22,
              top: 27 + spin.y * 22,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFD7724B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _open(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _FloatingEditor(
        title: '母球加塞',
        subtitle: '在母球上移动红点，设置击球位置',
        onReset: () => game.setSpinOffset(Vector2.zero()),
        resetLabel: '重置至中心',
        child: ValueListenableBuilder<Vector2>(
          valueListenable: game.spinNotifier,
          builder: (context, spin, _) => LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              void move(Offset position) {
                final center = Offset(side / 2, side / 2);
                var normalized = (position - center) / (side * .4);
                if (normalized.distance > 1) {
                  normalized = normalized / normalized.distance;
                }
                game.setSpinOffset(Vector2(normalized.dx, normalized.dy));
              }

              return Center(
                child: Semantics(
                  label: '放大的母球击点盘',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (d) => move(d.localPosition),
                    onPanUpdate: (d) => move(d.localPosition),
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: CustomPaint(
                        painter: CueBallPainter(
                          Offset(spin.x, spin.y),
                          expanded: true,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CueAngleControl extends StatelessWidget {
  const CueAngleControl({
    super.key,
    required this.angle,
    required this.onChanged,
    required this.enabled,
  });
  final double angle;
  final ValueChanged<double> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => _ControlTile(
    label: '${angle.round()}° 杆角',
    onTap: enabled ? () => _open(context) : null,
    child: SizedBox(
      width: 54,
      height: 54,
      child: CustomPaint(
        // The cue and cue ball share a contained 54 px canvas: at 0° the
        // shaft is horizontal, and at 90° it rises vertically without
        // escaping into the table area.
        painter: CueAnglePainter(angle, compact: true),
      ),
    ),
  );
  void _open(BuildContext context) {
    var current = angle;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void change(double value) {
            current = value.clamp(0, 90);
            onChanged(current);
            update(() {});
          }

          return _FloatingEditor(
            title: '球杆角度',
            subtitle: '上下拖动球杆，调整抬杆角度',
            onReset: () => change(0),
            resetLabel: '恢复水平 · 0°',
            child: Column(
              children: [
                Text(
                  '${current.round()}°',
                  style: const TextStyle(
                    color: controlGold,
                    fontSize: 38,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      void move(Offset point) {
                        final pivot = Offset(
                          size.width * .78,
                          size.height * .76,
                        );
                        final dx = math.max(1.0, pivot.dx - point.dx);
                        change(
                          math.atan2(pivot.dy - point.dy, dx) * 180 / math.pi,
                        );
                      }

                      return Semantics(
                        label: '可拖动的球杆角度盘',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (d) => move(d.localPosition),
                          onPanUpdate: (d) => move(d.localPosition),
                          child: SizedBox.expand(
                            child: CustomPaint(
                              painter: CueAnglePainter(current),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({required this.label, required this.child, this.onTap});
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onTap != null,
    child: Tooltip(
      message: label,
      child: Material(
        color: const Color(0xFF292C2C),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFF626764), width: 2),
        ),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _FloatingEditor extends StatelessWidget {
  const _FloatingEditor({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onReset,
    required this.resetLabel,
  });
  final String title, subtitle, resetLabel;
  final Widget child;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        width: math.min(400, available.width - 36),
        height: math.min(470, available.height - 36),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2923),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: controlGold.withValues(alpha: .35)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 36)],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF5F1E7),
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(resetLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: controlGold,
                  side: const BorderSide(color: Color(0xFF6C654E)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CueBallPainter extends CustomPainter {
  CueBallPainter(this.hitPoint, {this.expanded = false});
  final Offset hitPoint;
  final bool expanded;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        r = size.shortestSide * .43;
    if (expanded) {
      canvas.drawCircle(
        center + const Offset(0, 9),
        r,
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        center,
        r + 9,
        Paint()
          ..color = controlGold.withValues(alpha: .18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Colors.white, Color(0xFFF7F6EE), Color(0xFFAFB6AB)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    final cross = Paint()
      ..color = const Color(0xFFB4BDB2)
      ..strokeWidth = expanded ? 1 : .5;
    canvas.drawLine(
      center - Offset(r * .7, 0),
      center + Offset(r * .7, 0),
      cross,
    );
    canvas.drawLine(
      center - Offset(0, r * .7),
      center + Offset(0, r * .7),
      cross,
    );
    if (expanded) {
      canvas.drawCircle(
        center,
        r * .62,
        Paint()
          ..color = const Color(0x22919E91)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final dot = center + hitPoint * (size.shortestSide * .4);
    canvas.drawCircle(
      dot,
      expanded ? 8 : 2.8,
      Paint()..color = const Color(0xFFE56250),
    );
    canvas.drawCircle(
      dot,
      expanded ? 3 : 1,
      Paint()..color = const Color(0xFFFFB6A5),
    );
  }

  @override
  bool shouldRepaint(CueBallPainter old) =>
      old.hitPoint != hitPoint || old.expanded != expanded;
}

class CueAnglePainter extends CustomPainter {
  CueAnglePainter(this.angle, {this.compact = false});
  final double angle;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * .78, size.height * .76);
    final r = compact
        ? size.height * .21
        : math.min(size.width, size.height) * .14;
    final radians = angle * math.pi / 180;
    final length = compact
        ? size.width * .62
        : math.min(size.width * .7, size.height * .72);
    if (!compact) {
      final baseline = Paint()
        ..color = Colors.white24
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(12, pivot.dy),
        Offset(size.width - 12, pivot.dy),
        baseline,
      );
      for (int tick = 0; tick <= 90; tick += 15) {
        final rad = tick * math.pi / 180;
        final a = pivot + Offset(-math.cos(rad), -math.sin(rad)) * (length - 4);
        final b =
            pivot + Offset(-math.cos(rad), -math.sin(rad)) * (length - 12);
        canvas.drawLine(a, b, baseline);
      }
      canvas.drawArc(
        Rect.fromCircle(center: pivot, radius: length - 8),
        math.pi,
        math.pi / 2,
        false,
        Paint()
          ..color = const Color(0xFF485349)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawArc(
        Rect.fromCircle(center: pivot, radius: r + 24),
        math.pi,
        radians,
        false,
        Paint()
          ..color = controlGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final direction = Offset(-math.cos(radians), -math.sin(radians));
    canvas.drawLine(
      pivot + direction * (r + 5),
      pivot + direction * length,
      Paint()
        ..color = controlGold
        ..strokeWidth = compact ? 3 : 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      pivot + direction * (r + 5),
      pivot + direction * (r + (compact ? 9 : 26)),
      Paint()
        ..color = const Color(0xFFF3EDD9)
        ..strokeWidth = compact ? 2 : 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      pivot,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.4),
          colors: [Colors.white, Color(0xFFECEFE3), Color(0xFF949F91)],
        ).createShader(Rect.fromCircle(center: pivot, radius: r)),
    );
  }

  @override
  bool shouldRepaint(CueAnglePainter old) =>
      old.angle != angle || old.compact != compact;
}

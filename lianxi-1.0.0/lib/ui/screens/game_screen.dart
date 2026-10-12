import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../game/billiards_game.dart';
import '../../game/input/power_gauge.dart';
import '../../game/systems/ball_rack.dart';
import '../widgets/practice_controls.dart';
import '../widgets/pocketed_ball_tray.dart';
import 'settings_page.dart';

const _referencePreset = BallPreset(
  id: 'free_reference',
  name: '自由摆球',
  subtitle: '单球瞄准练习',
  icon: Icons.sports_golf,
  balls: [(9, -103, -45), (10, -10, -45), (11, 112, 50)],
  cueBallPosition: (-24, -4),
);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.gameMode, this.preset});
  final GameMode gameMode;
  final BallPreset? preset;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BilliardsGame _game;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _game = BilliardsGame(
      gameMode: widget.gameMode,
      initialPreset:
          widget.preset ??
          (widget.gameMode == GameMode.practice ? _referencePreset : null),
    );
    _game.rulesNotifier.addListener(_refresh);
    _game.pocketedBallsNotifier.addListener(_refresh);
    _game.stateNotifier.addListener(_refresh);
    _enableControlsWhenReady();
  }

  Future<void> _enableControlsWhenReady({bool resetAim = true}) async {
    await _game.loaded;
    if (!mounted) return;
    await _game.cueBall!.mounted;
    if (resetAim &&
        widget.gameMode == GameMode.practice &&
        widget.preset == null) {
      _game.setAimDirection(Vector2(.35, -.94));
    }
    _refresh();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _game.rulesNotifier.removeListener(_refresh);
    _game.pocketedBallsNotifier.removeListener(_refresh);
    _game.stateNotifier.removeListener(_refresh);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void _presets() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: controlInk,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择练习阵型',
              style: TextStyle(fontSize: 18, color: controlGold),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: BallPreset.presets.length,
              itemBuilder: (context, index) {
                final preset = BallPreset.presets[index];
                return ListTile(
                  leading: Icon(preset.icon, color: controlGold),
                  title: Text(preset.name),
                  subtitle: Text(preset.subtitle),
                  onTap: () {
                    Navigator.pop(context);
                    _game.loadPreset(preset);
                    _enableControlsWhenReady(resetAim: false);
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final practice = widget.gameMode == GameMode.practice;
    return Scaffold(
      backgroundColor: const Color(0xFF333433),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            final rail = (w * .06).clamp(54.0, 100.0);
            final dial = (h * .105).clamp(44.0, 80.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/floor-texture.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  left: w * .185,
                  right: w * .145,
                  top: 0,
                  bottom: 0,
                  child: GameWidget(game: _game),
                ),
                Positioned(
                  left: w * .123,
                  width: rail,
                  top: h * .225,
                  bottom: h * .115,
                  child: PowerGauge(game: _game),
                ),
                Positioned(
                  left: w * .86,
                  width: rail * .83,
                  top: h * .17,
                  bottom: h * .115,
                  child: FineAimWheel(game: _game),
                ),
                Positioned(
                  left: w * .865,
                  width: dial,
                  top: h * .035,
                  height: dial,
                  child: SpinControl(game: _game),
                ),
                Positioned(
                  // Keep this compact angle preview clear of both the table
                  // and the left power rail at every landscape size.
                  left: w * .07,
                  width: dial,
                  top: h * .035,
                  height: dial,
                  child: CueAngleControl(
                    angle: _game.cueElevationDegrees,
                    enabled: _game.canAim,
                    onChanged: (v) {
                      _game.setCueElevation(v);
                      setState(() {});
                    },
                  ),
                ),
                Positioned(
                  left: w * .185,
                  right: w * .145,
                  top: h * .013,
                  height: (h * .08).clamp(40.0, 64.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xE62E3030),
                      border: Border(
                        bottom: BorderSide(color: Colors.black54, width: 3),
                      ),
                    ),
                    child: Row(
                      children: [
                        _Tool(
                          icon: Icons.arrow_back_rounded,
                          label: '返回首页',
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          practice ? '自由练习' : '标准开局',
                          style: const TextStyle(
                            color: Color(0xFFE7E7DE),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (practice) ...[
                          const SizedBox(width: 12),
                          if (_game.pocketedBallsNotifier.value.isEmpty)
                            BallGroupIndicator(pocketedBalls: const [])
                          else
                            SizedBox(
                              width: ((w * .67) - 405).clamp(125.0, 220.0),
                              height: 34,
                              child: PocketedBallTray(
                                balls: _game.pocketedBallsNotifier.value,
                              ),
                            ),
                        ],
                        const Spacer(),
                        _Tool(
                          icon: _game.guidelineEnabled
                              ? Icons.visibility
                              : Icons.visibility_off,
                          label: '辅助线',
                          onTap: () {
                            _game.toggleGuideline();
                            setState(() {});
                          },
                        ),
                        _Tool(
                          icon: Icons.tune_rounded,
                          label: '设置',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                            if (mounted) {
                              _game.applySettings();
                              setState(() {});
                            }
                          },
                        ),
                        if (practice) ...[
                          _Tool(
                            icon: Icons.undo_rounded,
                            label: '撤销上一杆',
                            onTap: _game.canUndo
                                ? () {
                                    _game.undoLastShot();
                                    setState(() {});
                                  }
                                : null,
                          ),
                          _Tool(
                            icon: Icons.sports_baseball_rounded,
                            label: '球型练习',
                            onTap: _presets,
                          ),
                        ],
                        _Tool(
                          icon: Icons.refresh_rounded,
                          label: '重新摆球',
                          onTap: () {
                            practice
                                ? _game.resetFreePlay()
                                : _game.resetStandard();
                            _enableControlsWhenReady();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: label,
    icon: Icon(
      icon,
      color: onTap == null ? Colors.white24 : const Color(0xFFC4C7B9),
      size: 27,
    ),
    style: IconButton.styleFrom(
      minimumSize: const Size(46, 44),
      backgroundColor: const Color(0xFF121A1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(8),
    ),
  );
}

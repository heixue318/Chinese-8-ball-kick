import 'dart:async' as async;
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart' as f2d;

import '../audio/audio_manager.dart';
import '../rules/foul_detector.dart';
import '../rules/game_rules.dart';
import '../ui/settings/game_settings.dart';
import '../ui/practice_input.dart';
import 'components/ball.dart';
import 'components/cue_stick.dart';
import 'components/guideline.dart';
import 'components/pocket.dart';
import 'components/table.dart';
import 'input/aim_controller.dart';
import 'systems/ball_placement.dart';
import 'systems/ball_rack.dart';
import 'table_constants.dart';

enum GameState { aiming, shooting, ballsMoving, placingBall }

enum GameMode { standard, practice }

class BilliardsGame extends Forge2DGame
    with TapCallbacks, DragCallbacks
    implements PracticeInput {
  BilliardsGame({
    this.gameMode = GameMode.standard,
    this.initialPreset,
    bool enablePracticeMode = false,
  }) : practiceMode = gameMode == GameMode.practice || enablePracticeMode,
       super(gravity: Vector2.zero(), zoom: 3.2);

  final GameMode gameMode;
  final bool practiceMode;
  final BallPreset? initialPreset;

  GameState state = GameState.aiming;
  final List<Ball> balls = [];
  Ball? cueBall;

  @override
  Vector2 aimDirection = Vector2(1, 0);
  double power = 0.5;
  Vector2 spinOffset = Vector2.zero();
  double cueElevationDegrees = 0;
  double _verticalSpinAtStrike = 0;
  bool _verticalSpinApplied = false;

  bool guidelineEnabled = true;
  bool angleDisplayEnabled = true;

  final ValueNotifier<double> powerNotifier = ValueNotifier(0.5);
  @override
  final ValueNotifier<Vector2> spinNotifier = ValueNotifier(Vector2.zero());
  final ValueNotifier<GameRules> rulesNotifier = ValueNotifier(GameRules());
  final ValueNotifier<GameState> stateNotifier = ValueNotifier(
    GameState.aiming,
  );
  final ValueNotifier<List<int>> pocketedBallsNotifier = ValueNotifier([]);

  GameRules get rules => rulesNotifier.value;
  final ShotAnalysis _shotAnalysis = ShotAnalysis();
  late BallPlacement _ballPlacement;
  bool _trackingShot = false;
  double _shotGraceTimer = 0;
  double _ballsMovingTimer = 0;
  bool _placeBehindHeadString = false;

  // Undo support (practice mode only): snapshot of all ball states before each shot
  List<_BallSnapshot>? _undoSnapshot;
  List<int>? _undoPocketedBalls;
  bool get canUndo =>
      practiceMode && _undoSnapshot != null && state == GameState.aiming;

  // Deferred pocket queue to avoid mutating physics world during iteration
  final List<Ball> _pendingPockets = [];

  bool get isPlaceBehindHeadString => _placeBehindHeadString;

  late CueStick _cueStick;
  late Guideline _guideline;
  late Table _table;
  late AimController _aimController;

  async.Timer? _longPressTimer;
  async.Timer? _foulClearTimer;
  Vector2? _longPressWorldPos;

  @override
  bool get canAim =>
      state == GameState.aiming &&
      cueBall != null &&
      cueBall!.isMounted &&
      !cueBall!.isPocketed &&
      !_ballPlacement.isDragging;

  bool get canPlaceBalls =>
      state != GameState.ballsMoving &&
      state != GameState.shooting &&
      _ballPlacement.canStartPlacement(
        practiceMode: practiceMode,
        placingBall: state == GameState.placingBall,
      );

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    f2d.maxTranslation = 20.0;
    f2d.maxTranslationSquared = 20.0 * 20.0;

    await AudioManager.instance.init();

    final settings = GameSettings.instance;
    guidelineEnabled = settings.guidelineEnabled;
    angleDisplayEnabled = settings.angleDisplayEnabled;

    _ballPlacement = BallPlacement(repositionBall);

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2.zero();

    _table = Table(world: world);
    world.add(_table);

    for (var i = 0; i < TableConstants.pocketCenters.length; i++) {
      final center = TableConstants.pocketCenters[i];
      world.add(
        Pocket(
          index: i,
          center: center,
          radius: TableConstants.pocketRadiusAt(i),
          onBallPocketed: _onBallPocketed,
        ),
      );
    }

    _cueStick = CueStick();
    world.add(_cueStick);

    _guideline = Guideline(balls: balls);
    world.add(_guideline);

    if (gameMode == GameMode.standard) {
      _setupStandardBalls();
    } else {
      _setupPracticeBalls();
    }

    _aimController = AimController(this);
  }

  Vector2 inputToWorld(Vector2 canvasPosition) {
    final worldPos = screenToWorld(canvasPosition);
    worldPos.y /= TableConstants.perspectiveYScale;
    return worldPos;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_ballPlacement.isDragging) return;
    final worldPos = inputToWorld(event.canvasPosition);
    if (canPlaceBalls) {
      _longPressWorldPos = worldPos.clone();
      _longPressTimer?.cancel();
      final delay = state == GameState.placingBall
          ? const Duration(milliseconds: 50)
          : const Duration(milliseconds: 280);
      _longPressTimer = async.Timer(delay, () {
        if (_longPressWorldPos != null) {
          _ballPlacement.onLongPress(
            _longPressWorldPos!,
            balls,
            practiceMode: practiceMode,
            placingBall: state == GameState.placingBall,
            behindHeadString: _placeBehindHeadString,
          );
        }
      });
    }
    if (state == GameState.placingBall && !practiceMode) return;
    _aimController.updateFromCanvasPoint(event.canvasPosition);
  }

  @override
  void onTapUp(TapUpEvent event) {
    _cancelLongPressTimer();
    if (_ballPlacement.isDragging) {
      _ballPlacement.onDragEnd();
      if (state == GameState.placingBall &&
          cueBall != null &&
          !cueBall!.isPocketed) {
        _finishCueBallPlacement();
      }
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _cancelLongPressTimer();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _aimController.reset();
    final savedPos = _longPressWorldPos;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_ballPlacement.isDragging) return;
    if (canPlaceBalls && savedPos != null) {
      _ballPlacement.onLongPress(
        savedPos,
        balls,
        practiceMode: practiceMode,
        placingBall: state == GameState.placingBall,
        behindHeadString: _placeBehindHeadString,
      );
    }
    _longPressWorldPos = null;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_ballPlacement.isDragging) {
      _ballPlacement.onDragUpdate(inputToWorld(event.canvasEndPosition));
      return;
    }
    if (state == GameState.placingBall) return;
    _aimController.updateFromCanvasPoint(event.canvasEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _cancelLongPressTimer();
    _ballPlacement.onDragEnd();
    if (state == GameState.placingBall &&
        cueBall != null &&
        !cueBall!.isPocketed) {
      _finishCueBallPlacement();
    }
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressWorldPos = null;
  }

  void _setupStandardBalls() {
    _setupBalls();
    _placeBehindHeadString = true;
    state = GameState.placingBall;
    _setState(GameState.placingBall);
    _guideline.enabled = false;
  }

  void _setupPracticeBalls() {
    if (initialPreset != null) {
      _setupFromPreset(initialPreset!);
    } else {
      _setupBalls();
    }
  }

  void loadPreset(BallPreset preset) {
    _resetTransientState();
    rules.reset();
    rulesNotifier.value = GameRules();
    _setupFromPreset(preset);
    state = GameState.aiming;
    _setState(GameState.aiming);
    _updateAimVisuals();
  }

  void _resetTransientState() {
    _undoSnapshot = null;
    _undoPocketedBalls = null;
    pocketedBallsNotifier.value = [];
    _pendingPockets.clear();
    _trackingShot = false;
    _shotGraceTimer = 0;
    _ballsMovingTimer = 0;
    _placeBehindHeadString = false;
  }

  void _setupFromPreset(BallPreset preset) {
    _clearAllBalls();
    final cuePos = preset.cueBallPosition;
    final safeCuePosition = BallPlacement.clampToTable(
      Vector2(cuePos?.$1 ?? TableConstants.headStringX - 20, cuePos?.$2 ?? 0),
    );
    cueBall = Ball(number: 0, position: safeCuePosition);
    world.add(cueBall!);
    balls.add(cueBall!);

    for (final (number, x, y) in preset.balls) {
      final ball = Ball(
        number: number,
        position: BallPlacement.clampToTable(Vector2(x, y)),
      );
      world.add(ball);
      balls.add(ball);
    }
    _wireShotListeners();
  }

  void _setupBalls() {
    _clearAllBalls();
    cueBall = BallRack.createCueBall();
    world.add(cueBall!);
    balls.add(cueBall!);

    final racked = BallRack.createRackedBalls(world: world);
    for (final ball in racked) {
      world.add(ball);
      balls.add(ball);
    }
    _wireShotListeners();
  }

  void _clearAllBalls() {
    for (final ball in List<Ball>.from(balls)) {
      ball.removeFromParent();
    }
    balls.clear();
    cueBall = null;
  }

  void _wireShotListeners() {
    for (final ball in balls) {
      ball.onContact = _onBallContact;
    }
  }

  void _onBallContact(Ball self, Object other) {
    if (!_trackingShot) return;

    if (other is Ball) {
      final speed =
          (self.body.linearVelocity - other.body.linearVelocity).length;
      AudioManager.instance.playBallCollision(speed: speed);
      if (self.isCueBall) {
        _shotAnalysis.cueBallHitAnyBall = true;
        _shotAnalysis.firstBallHit ??= other;
        _applyVerticalSpinAfterContact(self, other);
      } else if (other.isCueBall) {
        _shotAnalysis.cueBallHitAnyBall = true;
        _shotAnalysis.firstBallHit ??= self;
        _applyVerticalSpinAfterContact(other, self);
      }
    } else if (other is CushionSegment) {
      AudioManager.instance.playCushionHit(
        speed: self.body.linearVelocity.length,
      );
      _shotAnalysis.anyBallHitCushion = true;
    } else {
      // fixture.userData might be the cushionMarker
      if (identical(other, CushionSegment.cushionMarker)) {
        AudioManager.instance.playCushionHit(
          speed: self.body.linearVelocity.length,
        );
        _shotAnalysis.anyBallHitCushion = true;
      }
    }
  }

  void _onBallPocketed(Ball ball, [Pocket? pocket]) {
    if (ball.isPocketed) return;
    ball.isPocketed = true;
    if (!ball.isCueBall && !pocketedBallsNotifier.value.contains(ball.number)) {
      pocketedBallsNotifier.value = [
        ...pocketedBallsNotifier.value,
        ball.number,
      ];
    }

    if (state == GameState.ballsMoving || state == GameState.shooting) {
      _shotAnalysis.pocketedBallNumbers.add(ball.number);
      if (ball.isCueBall) {
        _shotAnalysis.cueBallPocketed = true;
      }
    }

    AudioManager.instance.playBallPocketed();
    ball.pocket();
    if (ball.isCueBall) {
      _placeBehindHeadString = false;
      state = GameState.placingBall;
      _setState(GameState.placingBall);
      _cueStick.hide();
      _guideline.enabled = false;
      ball.restoreForPlacement(Vector2(TableConstants.headStringX, 0));
    }
  }

  void _finishCueBallPlacement() {
    _placeBehindHeadString = false;
    state = GameState.aiming;
    _setState(GameState.aiming);
    _updateAimVisuals();
  }

  @override
  void setAimDirection(Vector2 direction) {
    if (!canAim) return;
    aimDirection = direction.normalized();
    _updateAimVisuals();
  }

  @override
  void setPower(double value) {
    power = value.clamp(0.0, 1.0);
    powerNotifier.value = power;
    _updateAimVisuals();
  }

  @override
  void setSpinOffset(Vector2 offset) {
    spinOffset = offset.clone();
    spinNotifier.value = spinOffset;
    _updateAimVisuals();
  }

  /// Cue elevation reduces the horizontal impulse.  We preserve a small
  /// controllable component at high angles because this app models table-plane
  /// play rather than airborne jump/masse shots.
  void setCueElevation(double value) {
    cueElevationDegrees = value.clamp(0.0, 90.0);
    _updateAimVisuals();
  }

  void _applyVerticalSpinAfterContact(Ball cue, Ball object) {
    if (_verticalSpinApplied || _verticalSpinAtStrike.abs() < 0.02) return;
    _verticalSpinApplied = true;
    final contactAxis = (object.body.position - cue.body.position).normalized();
    if (contactAxis.length2 < 0.001) return;

    // In the table plane, top spin (negative screen-Y hit point) carries the
    // cue ball forward and draw pulls it back.  This is intentionally bounded
    // so it supplements Forge2D's collision response instead of overpowering
    // the target ball at thin cuts.
    final impulse =
        -_verticalSpinAtStrike * power * TableConstants.maxShotPower * 0.055;
    cue.body.applyLinearImpulse(contactAxis * impulse);
  }

  void toggleGuideline() {
    guidelineEnabled = !guidelineEnabled;
    GameSettings.instance.setGuidelineEnabled(guidelineEnabled);
    _guideline.enabled = guidelineEnabled;
  }

  void applySettings() {
    final settings = GameSettings.instance;
    guidelineEnabled = settings.guidelineEnabled;
    angleDisplayEnabled = settings.angleDisplayEnabled;
    _guideline.enabled = guidelineEnabled;
    _guideline.showAngle = angleDisplayEnabled;
    _guideline.showObjectPath = settings.objectPathEnabled;
    _guideline.showDeflection = settings.deflectionLineEnabled;
    _guideline.showTriangle = settings.triangleEnabled;
  }

  @override
  Future<void> shoot() async {
    if (!canAim || cueBall == null) return;

    if (practiceMode) {
      _undoPocketedBalls = List<int>.from(pocketedBallsNotifier.value);
      _undoSnapshot = balls
          .map(
            (b) => _BallSnapshot(
              number: b.number,
              position: b.body.position.clone(),
              isPocketed: b.isPocketed,
              isVisible: b.isVisible,
            ),
          )
          .toList();
    }

    _beginShotTracking();
    state = GameState.shooting;
    _setState(GameState.shooting);
    final cue = cueBall!;
    final dir = aimDirection.normalized();

    await _cueStick.animateStrike(power);

    final elevationRadians = cueElevationDegrees * math.pi / 180;
    final horizontalEfficiency = math
        .pow(math.cos(elevationRadians), 2)
        .toDouble()
        .clamp(0.12, 1.0)
        .toDouble();
    final impulseStrength =
        power * TableConstants.maxShotPower * horizontalEfficiency;
    AudioManager.instance.playCueHit(power: power);
    cue.body.applyLinearImpulse(dir * impulseStrength);

    final perp = Vector2(-dir.y, dir.x);
    cue.body.applyLinearImpulse(
      perp *
          spinOffset.x *
          impulseStrength *
          TableConstants.shotSideSpinFraction,
    );

    // Forge2D's planar angular velocity represents side English correctly.
    // Follow/draw is resolved at the first object-ball contact above.
    cue.body.angularVelocity = spinOffset.x * 12 * horizontalEfficiency;
    _verticalSpinAtStrike = spinOffset.y;
    _verticalSpinApplied = false;

    _cueStick.hide();
    _guideline.enabled = false;
    _shotGraceTimer = 0.15;
    _ballsMovingTimer = 0;
    state = GameState.ballsMoving;
    _setState(GameState.ballsMoving);
  }

  void _beginShotTracking() {
    _shotAnalysis.reset();
    _trackingShot = true;
  }

  void _endShotTracking() {
    _trackingShot = false;
    final foul = FoulDetector.analyze(_shotAnalysis);
    if (foul.isFoul) AudioManager.instance.playFoul();
    rules.onShotComplete(_shotAnalysis, foul);
    rulesNotifier.value = rules.clone();

    _foulClearTimer?.cancel();
    if (foul.isFoul) {
      _foulClearTimer = async.Timer(const Duration(seconds: 3), () {
        rules.lastFoul = null;
        rulesNotifier.value = rules.clone();
      });
    }
  }

  void resetStandard() {
    rules.reset();
    rulesNotifier.value = GameRules();
    _ballPlacement.cancel();
    _resetTransientState();
    state = GameState.aiming;
    _setState(GameState.aiming);
    _setupStandardBalls();
    _updateAimVisuals();
  }

  void resetFreePlay() {
    rules.reset();
    rulesNotifier.value = GameRules();
    _ballPlacement.cancel();
    _resetTransientState();
    state = GameState.aiming;
    _setState(GameState.aiming);
    _setupPracticeBalls();
    _updateAimVisuals();
  }

  void undoLastShot() {
    if (!canUndo || _undoSnapshot == null) return;
    for (final snap in _undoSnapshot!) {
      final ball = balls.firstWhere((b) => b.number == snap.number);
      if (snap.isPocketed) {
        ball.pocket();
      } else {
        ball.reposition(snap.position);
      }
    }
    pocketedBallsNotifier.value = _undoPocketedBalls ?? [];
    _undoPocketedBalls = null;
    rules.reset();
    final analysis = ShotAnalysis()
      ..pocketedBallNumbers.addAll(pocketedBallsNotifier.value);
    rules.onShotComplete(analysis, FoulResult.none);
    rulesNotifier.value = rules.clone();
    _undoSnapshot = null;
    state = GameState.aiming;
    _setState(GameState.aiming);
    _updateAimVisuals();
  }

  void repositionBall(Ball ball, Vector2 newPosition) {
    final clamped = BallPlacement.clampToTable(newPosition);
    ball.reposition(clamped);
    if (ball.isCueBall && state == GameState.placingBall) {
      _finishCueBallPlacement();
    }
  }

  void _updateAimVisuals() {
    if (cueBall == null || cueBall!.isPocketed || !cueBall!.isMounted) return;
    final pos = cueBall!.body.position;
    final angle = math.atan2(aimDirection.y, aimDirection.x);
    _cueStick.showAiming(pos, angle);
    final settings = GameSettings.instance;
    _guideline.cueBallPosition = pos.clone();
    _guideline.aimDirection = aimDirection.clone();
    _guideline.spinOffset = spinOffset.clone();
    _guideline.cueElevationDegrees = cueElevationDegrees;
    _guideline.power = power;
    _guideline.enabled = guidelineEnabled;
    _guideline.showAngle = angleDisplayEnabled;
    _guideline.showObjectPath = settings.objectPathEnabled;
    _guideline.showDeflection = settings.deflectionLineEnabled;
    _guideline.showTriangle = settings.triangleEnabled;
  }

  void _setState(GameState newState) {
    stateNotifier.value = newState;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _enforceCushionBounds();

    // Distance-based pocket detection — catches balls that the sensor
    // might miss due to physics step ordering or high-speed tunneling.
    // Deferred: collect candidates first, then process after physics is safe.
    if (state != GameState.aiming) {
      _checkPocketProximity(dt);
      _processPendingPockets();
    }

    if (state == GameState.ballsMoving ||
        (state == GameState.placingBall && _trackingShot)) {
      _ballsMovingTimer += dt;
      if (_shotGraceTimer > 0) {
        _shotGraceTimer -= dt;
      } else if (!_anyBallMoving() || _ballsMovingTimer > 15.0) {
        if (_ballsMovingTimer > 15.0) {
          _forceStopAllBalls();
        }
        if (_trackingShot) {
          _endShotTracking();
        }
        if (state == GameState.ballsMoving) {
          state = GameState.aiming;
          _setState(GameState.aiming);
          _updateAimVisuals();
        }
      }
    } else if (state == GameState.aiming) {
      _updateAimVisuals();
    }
  }

  /// Final guard for high-speed contacts and pocket-lip seams.  Forge2D still
  /// handles normal impacts; this only corrects a body after it has crossed a
  /// cushion nose.  The same nose constants drive the prediction renderer.
  void _enforceCushionBounds() {
    final minX =
        -TableConstants.cushionNoseHalfLength + TableConstants.ballRadius;
    final maxX =
        TableConstants.cushionNoseHalfLength - TableConstants.ballRadius;
    final minY = TableConstants.cushionNoseTop + TableConstants.ballRadius;
    final maxY = TableConstants.cushionNoseBottom - TableConstants.ballRadius;

    for (final ball in balls) {
      // Ball components are added asynchronously to the Forge2D world.  Do
      // not read their late-initialized body during the brief mounting frame.
      if (!ball.isMounted ||
          ball.isPocketed ||
          !ball.isVisible ||
          !ball.body.isActive) {
        continue;
      }
      final position = ball.body.position;
      if (_isInsidePocketMouth(position)) continue;

      final outsideX = position.x < minX || position.x > maxX;
      final outsideY = position.y < minY || position.y > maxY;
      if (!outsideX && !outsideY) continue;

      final clamped = Vector2(
        position.x.clamp(minX, maxX),
        position.y.clamp(minY, maxY),
      );
      final velocity = ball.body.linearVelocity.clone();
      if (outsideX &&
          ((position.x < minX && velocity.x < 0) ||
              (position.x > maxX && velocity.x > 0))) {
        velocity.x = -velocity.x * TableConstants.effectiveCushionRestitution;
      }
      if (outsideY &&
          ((position.y < minY && velocity.y < 0) ||
              (position.y > maxY && velocity.y > 0))) {
        velocity.y = -velocity.y * TableConstants.effectiveCushionRestitution;
      }
      ball.body.setTransform(clamped, ball.body.angle);
      ball.body.linearVelocity = velocity;
    }
  }

  bool _isInsidePocketMouth(Vector2 position) {
    for (var i = 0; i < TableConstants.pocketCenters.length; i++) {
      final mouthRadius =
          TableConstants.pocketRadiusAt(i) + TableConstants.ballRadius * 1.8;
      if ((position - TableConstants.pocketCenters[i]).length < mouthRadius) {
        return true;
      }
    }
    return false;
  }

  void _checkPocketProximity(double dt) {
    for (final ball in balls) {
      // Standard opening adds sixteen bodies asynchronously.  A partially
      // mounted rack must never be queried before Forge2D creates each body.
      if (!ball.isMounted || ball.isPocketed || !ball.isVisible) continue;
      final pos = ball.body.position;

      double closestDist = double.infinity;
      int closestIdx = -1;
      for (var i = 0; i < TableConstants.pocketCenters.length; i++) {
        final d = (pos - TableConstants.pocketCenters[i]).length;
        if (d < closestDist) {
          closestDist = d;
          closestIdx = i;
        }
      }
      if (closestIdx < 0) continue;

      final pocketR = TableConstants.pocketRadiusAt(closestIdx);
      // Use the centre of the pictured hole, not first contact with its lip.
      // The swept test prevents a fast ball crossing the small capture zone
      // between two frames without being collected.
      final hole = TableConstants.pocketCenters[closestIdx];
      final previous = pos - ball.body.linearVelocity * dt;
      final travel = pos - previous;
      final along = travel.length2 > 0.0001
          ? ((hole - previous).dot(travel) / travel.length2).clamp(0.0, 1.0)
          : 1.0;
      final sweptDistance = (previous + travel * along - hole).length;
      if (closestDist < pocketR * .6 || sweptDistance < pocketR * .6) {
        if (!_pendingPockets.contains(ball)) {
          _pendingPockets.add(ball);
        }
        continue;
      }

      // Gravity well: pull ball toward pocket when in outer zone.
      // Makes pocketing feel snappy — no lingering at the lip.
      final pullZone = pocketR * 1.4;
      final speed = ball.body.linearVelocity.length;
      if (closestDist < pullZone && speed < 120) {
        final toCenter = TableConstants.pocketCenters[closestIdx] - pos;
        if (toCenter.length > 0.01) {
          toCenter.normalize();
          final t = 1.0 - closestDist / pullZone;
          ball.body.applyForce(toCenter * (t * 1200.0));
        }
      }
    }
  }

  void _processPendingPockets() {
    if (_pendingPockets.isEmpty) return;
    final batch = List<Ball>.from(_pendingPockets);
    _pendingPockets.clear();
    for (final ball in batch) {
      _onBallPocketed(ball);
    }
  }

  bool _anyBallMoving() {
    for (final ball in balls) {
      if (ball.isMounted && ball.isMoving) return true;
    }
    return false;
  }

  void _forceStopAllBalls() {
    for (final ball in balls) {
      if (ball.isMounted && !ball.isPocketed && ball.body.isActive) {
        ball.body.linearVelocity = Vector2.zero();
        ball.body.angularVelocity = 0;
      }
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitCamera(size);
  }

  void _fitCamera(Vector2 size) {
    const marginX = 4.0;
    const marginY = 8.0;

    final tableW =
        TableConstants.length + TableConstants.railWidth * 2 + marginX;
    final tableH =
        (TableConstants.width + TableConstants.railWidth * 2 + marginY) *
        TableConstants.perspectiveYScale;
    final scaleX = size.x / tableW;
    final scaleY = size.y / tableH;
    final zoom = math.min(scaleX, scaleY);
    camera.viewfinder.zoom = zoom;
    camera.viewfinder.position = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(1, TableConstants.perspectiveYScale);
    super.render(canvas);
    canvas.restore();
  }

  @override
  void onRemove() {
    _cancelLongPressTimer();
    _foulClearTimer?.cancel();
    powerNotifier.dispose();
    spinNotifier.dispose();
    rulesNotifier.dispose();
    stateNotifier.dispose();
    pocketedBallsNotifier.dispose();
    super.onRemove();
  }
}

class _BallSnapshot {
  _BallSnapshot({
    required this.number,
    required this.position,
    required this.isPocketed,
    required this.isVisible,
  });

  final int number;
  final Vector2 position;
  final bool isPocketed;
  final bool isVisible;
}

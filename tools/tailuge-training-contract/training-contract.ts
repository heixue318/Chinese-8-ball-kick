/**
 * Platform-neutral contract for the training layer around Tailuge.
 *
 * It intentionally has no dependency on the Tailuge physics implementation or
 * UI. The adapter owns coordinate conversion and calls its real predictor.
 */

export type Metres = number;
export type Seconds = number;

export interface Vec2 {
  /** Tailuge coordinates are table-centred metres: +x right, +y up. */
  readonly x: Metres;
  readonly y: Metres;
}

export interface TrainingTable {
  readonly coordinateSpace: 'table-centred-metres';
  readonly width: Metres;
  readonly height: Metres;
  readonly ballRadius: Metres;
  /** Calibrated pocket centres, never inferred from a visual mesh. */
  readonly pockets: readonly Vec2[];
  readonly calibrationId: string;
}

export interface TrainingBall {
  /** 0 is the cue ball. Object-ball identifiers must remain stable in a drill. */
  readonly id: number;
  readonly position: Vec2;
  readonly pocketed: boolean;
}

export interface TrainingLayout {
  readonly balls: readonly TrainingBall[];
}

export interface ShotControls {
  readonly angleDegrees: number;
  readonly speed: number;
  readonly side: number;
  readonly top: number;
}

export type PlacementResult =
  | { readonly accepted: true; readonly layout: TrainingLayout }
  | {
      readonly accepted: false;
      readonly reason: 'moving' | 'unknown-ball' | 'outside-table' | 'pocket-area' | 'overlap';
    };

export type DrillPreset = 'straight' | 'cut' | 'one-cushion' | 'two-cushion';

export interface RecordedFrame {
  readonly seconds: Seconds;
  /** State copied from the predictor; callers must not retain live engine objects. */
  readonly layout: TrainingLayout;
}

export interface ShotReview {
  readonly before: TrainingLayout;
  readonly controls: ShotControls;
  readonly frames: readonly RecordedFrame[];
  readonly after: TrainingLayout;
}

/** A physics result is authoritative only for the exact model/calibration/input tuple. */
export interface PhysicsPrediction {
  readonly kind: 'physics-prediction';
  readonly modelId: string;
  readonly calibrationId: string;
  readonly input: { readonly layout: TrainingLayout; readonly controls: ShotControls };
  readonly frames: readonly RecordedFrame[];
  readonly events: readonly { readonly seconds: Seconds; readonly type: string; readonly ballId: number; readonly otherBallId?: number }[];
}

/**
 * A geometric overlay is a coaching hint, never a prediction or a replay.
 * `ideal-geometry` must be rendered with its label and must not be merged into
 * PhysicsPrediction frames/events.
 */
export interface IdealGeometryHint {
  readonly kind: 'ideal-geometry';
  readonly label: '理想几何提示';
  readonly assumptions: readonly ('equal-balls' | 'mirror-cushion' | 'no-spin' | 'no-throw' | 'no-friction' | 'circular-pocket')[];
  readonly cuePath: readonly Vec2[];
  readonly ghostBall?: Vec2;
  readonly contactPoint?: Vec2;
  readonly objectPath?: readonly Vec2[];
}

export interface TrainingPhysicsAdapter {
  readonly table: TrainingTable;
  snapshot(): TrainingLayout;
  moving(): boolean;
  restore(layout: TrainingLayout): void;
  strike(controls: ShotControls): boolean;
  /** Must execute Tailuge's real simulation; ideal geometry is not an implementation. */
  predict(layout: TrainingLayout, controls: ShotControls): PhysicsPrediction;
}

export function validateLayout(table: TrainingTable, layout: TrainingLayout): PlacementResult {
  const cue = layout.balls.find((ball) => ball.id === 0);
  if (!cue || cue.pocketed) return { accepted: false, reason: 'unknown-ball' };
  const ids = new Set<number>();
  for (const ball of layout.balls) {
    if (!Number.isInteger(ball.id) || ball.id < 0 || ids.has(ball.id)) return { accepted: false, reason: 'unknown-ball' };
    ids.add(ball.id);
    if (ball.pocketed) continue;
    if (Math.abs(ball.position.x) > table.width / 2 - table.ballRadius || Math.abs(ball.position.y) > table.height / 2 - table.ballRadius) return { accepted: false, reason: 'outside-table' };
    if (table.pockets.some((pocket) => Math.hypot(ball.position.x - pocket.x, ball.position.y - pocket.y) < table.ballRadius)) return { accepted: false, reason: 'pocket-area' };
  }
  for (let i = 0; i < layout.balls.length; i += 1) for (let j = 0; j < i; j += 1) {
    const a = layout.balls[i], b = layout.balls[j];
    if (!a.pocketed && !b.pocketed && Math.hypot(a.position.x - b.position.x, a.position.y - b.position.y) < 2 * table.ballRadius) return { accepted: false, reason: 'overlap' };
  }
  return { accepted: true, layout };
}

/** Keeps the UI contract explicit when both layers are supplied to a renderer. */
export function presentationLayers(prediction: PhysicsPrediction | undefined, hint: IdealGeometryHint | undefined) {
  return { prediction, hint } as const;
}

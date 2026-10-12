import { Vector3 } from 'three';
import { Ball, State } from '../vendor/tailuge/model/ball';
import { Collision } from '../vendor/tailuge/model/physics/collision';
import { Cushion } from '../vendor/tailuge/model/physics/cushion';
import { Knuckle } from '../vendor/tailuge/model/physics/knuckle';
import { Pocket } from '../vendor/tailuge/model/physics/pocket';
import { cueStrike, mathavanAdapter, surfaceVelocityFull } from '../vendor/tailuge/model/physics/physics';
import { R } from '../vendor/tailuge/model/physics/constants';
import { TableGeometry } from '../vendor/tailuge/view/tablegeometry';
import { PocketGeometry } from '../vendor/tailuge/view/pocketgeometry';
import { applyCalibrationProfile, initialChineseEightBallProfile, type CalibrationProfile } from './calibration';

// Tailuge stores constants at module scope; profiles are reapplied for every simulator step.
applyCalibrationProfile(initialChineseEightBallProfile);
export const config = Object.freeze({ width: initialChineseEightBallProfile.table.playingLength, height: initialChineseEightBallProfile.table.playingWidth, radius: initialChineseEightBallProfile.ball.radius, mass: initialChineseEightBallProfile.ball.mass, dt: initialChineseEightBallProfile.simulation.dt, maxSeconds: initialChineseEightBallProfile.simulation.maxSeconds, rolling: initialChineseEightBallProfile.cloth.rollingFriction, sliding: initialChineseEightBallProfile.cloth.slidingFriction });
export const geometry = {
  get pockets() { return PocketGeometry.pocketCenters; },
  get jaws() { return PocketGeometry.knuckles; },
};
/** Platform-neutral shot contract. Future question banks should persist this shape. */
export type BallSeed = { x: number; y: number };
export type ShotInput = { angle: number; speed: number; side: number; top: number };
export type ShotSeed = ShotInput & { balls: BallSeed[] };
/** @deprecated Use ShotSeed. Kept for phase-one verification callers. */
export type Seed = ShotSeed;
export type BallSnapshot = { id: number; pos: number[]; vel: number[]; spin: number[]; state: State; slip: number };
export type PhysicsEvent = { tick: number; type: string; ball: number; other?: number };
export type SimulationFrame = { tick: number; balls: BallSnapshot[] };
export type SimulationRun = { frames: SimulationFrame[]; events: PhysicsEvent[]; ticks: number };
export type ShotOutcome = { potted: number[]; cuePotted: boolean; firstContact?: number; cushions: number; duration: number };
export const scenarios: Record<string, { name: string; seed: Seed }> = {
  collision: { name: '正碰', seed: { balls: [{ x: -0.6, y: 0 }, { x: 0, y: 0 }], angle: 0, speed: 1.8, side: 0, top: 0 } },
  slide: { name: '滑动 → 滚动', seed: { balls: [{ x: -0.9, y: 0.25 }], angle: 0, speed: 1, side: 0, top: 0 } },
  follow: { name: '高杆跟进', seed: { balls: [{ x: -0.35, y: 0 }, { x: 0, y: 0 }], angle: 0, speed: 2, side: 0, top: 0.45 } },
  draw: { name: '低杆回拉', seed: { balls: [{ x: -0.35, y: 0 }, { x: 0, y: 0 }], angle: 0, speed: 2, side: 0, top: -0.45 } },
  side: { name: '侧塞碰库', seed: { balls: [{ x: 0.45, y: 0.05 }], angle: 20, speed: 2, side: 0.45, top: 0 } },
  rail: { name: '无塞碰库', seed: { balls: [{ x: 0.45, y: 0.05 }], angle: 20, speed: 2, side: 0, top: 0 } },
  pocket: { name: '中袋落袋', seed: { balls: [{ x: 0, y: 0.25 }], angle: 90, speed: 1, side: 0, top: 0 } },
  corner: { name: '角袋落袋', seed: { balls: [{ x: 0.9, y: 0.3 }], angle: 42.49, speed: 1, side: 0, top: 0 } },
};
export class Simulator {
  balls: Ball[]; tick = 0; events: PhysicsEvent[] = [];
  constructor(public seed: ShotSeed, public readonly profile: CalibrationProfile = initialChineseEightBallProfile) {
    applyCalibrationProfile(profile);
    if (!seed.balls.length || seed.balls.length > 16 || ![seed.angle, seed.speed, seed.side, seed.top].every(Number.isFinite) || seed.speed < 0 || seed.speed > 5 || Math.hypot(seed.side, seed.top) > 0.451) throw new Error('Invalid shot');
    this.balls = seed.balls.map((p, index) => {
      if (!Number.isFinite(p.x) || !Number.isFinite(p.y) || Math.abs(p.x) > TableGeometry.tableX || Math.abs(p.y) > TableGeometry.tableY) throw new Error('Ball outside table');
      const b = new Ball(new Vector3(p.x, p.y, 0));
      // Stable IDs also make upstream pocket resting depth reproducible.
      Object.defineProperty(b, 'id', { value: index }); return b;
    });
    this.balls.forEach((a, i) => this.balls.slice(i + 1).forEach(b => { if (a.pos.distanceTo(b.pos) < 2 * R) throw new Error('Overlapping balls'); }));
    const strike = cueStrike(seed.angle * Math.PI / 180, seed.speed, new Vector3(seed.side, seed.top, 0));
    this.balls[0].vel.copy(strike.vel); this.balls[0].rvel.copy(strike.rvel); this.balls[0].state = seed.speed ? State.Sliding : State.Stationary;
  }
  get done() { return this.balls.every(b => !b.inMotion()); }
  step() {
    applyCalibrationProfile(this.profile);
    if (this.done) return;
    if (this.tick >= this.profile.simulation.maxSeconds / this.profile.simulation.dt) throw new Error('Simulation time limit exceeded');
    const dt = this.profile.simulation.dt;
    // Upstream contact formulas; bounded fixed-step scheduler with separating-contact guards.
    for (let i = 0; i < this.balls.length; i++) for (let j = i + 1; j < this.balls.length; j++) {
      const a = this.balls[i], b = this.balls[j];
      if (Collision.willCollide(a, b, dt) && b.pos.clone().sub(a.pos).dot(b.vel.clone().sub(a.vel)) < 0) {
        Collision.collide(a, b); this.events.push({ tick: this.tick, type: 'collision', ball: i, other: j });
      }
    }
    for (const [i, b] of this.balls.entries()) {
      if (b.onTable()) {
        const p = b.futurePosition(dt);
        if (Math.abs(p.x) >= TableGeometry.tableX || Math.abs(p.y) >= TableGeometry.tableY) {
          const outward = (Math.abs(p.x) >= TableGeometry.tableX && p.x * b.vel.x > 0) || (Math.abs(p.y) >= TableGeometry.tableY && p.y * b.vel.y > 0);
          const rail = outward ? Cushion.bounceAny(b, dt, true, mathavanAdapter) : undefined;
          if (rail) { b.state = State.Sliding; this.events.push({ tick: this.tick, type: 'rail', ball: i }); }
          else {
            const jaw = Knuckle.findBouncing(b, dt);
            if (jaw && b.pos.clone().sub(jaw.pos).dot(b.vel) < 0) { jaw.bounce(b); b.state = State.Sliding; this.events.push({ tick: this.tick, type: 'jaw', ball: i }); }
            else { const pocket = Pocket.findPocket(PocketGeometry.pocketCenters, b, dt); if (pocket) { pocket.fall(b, dt); this.events.push({ tick: this.tick, type: 'pot', ball: i }); } }
          }
        }
      }
      const before = b.state; b.update(dt); b.fround();
      if (before !== b.state) this.events.push({ tick: this.tick, type: b.state, ball: i });
      if (![...b.pos.toArray(), ...b.vel.toArray(), ...b.rvel.toArray()].every(Number.isFinite)) throw new Error('Non-finite physics state');
      if (b.onTable() && (Math.abs(b.pos.x) > config.width / 2 + 0.2 || Math.abs(b.pos.y) > config.height / 2 + 0.2)) throw new Error('Ball escaped pocket geometry');
    }
    this.tick++;
  }
  snapshot(): BallSnapshot[] { return this.balls.map(b => ({ id: b.id, pos: b.pos.toArray(), vel: b.vel.toArray(), spin: b.rvel.toArray(), state: b.state, slip: surfaceVelocityFull(b.vel, b.rvel).length() })); }
}
/** Runs a complete shot. Both UI preview and real-time animation use this exact solver. */
export function simulateShot(seed: ShotSeed, stride = 10, profile: CalibrationProfile = initialChineseEightBallProfile): SimulationRun {
  const sim = new Simulator(structuredClone(seed), profile); const frames = [{ tick: 0, balls: sim.snapshot() }];
  while (!sim.done) { sim.step(); if (sim.tick % stride === 0 || sim.done) frames.push({ tick: sim.tick, balls: sim.snapshot() }); }
  return { frames, events: sim.events, ticks: sim.tick };
}
export const predict = simulateShot;
export function analyzeShot(run: SimulationRun): ShotOutcome {
  const potted = [...new Set(run.events.filter(e => e.type === 'pot').map(e => e.ball))];
  return {
    potted,
    cuePotted: potted.includes(0),
    firstContact: run.events.find(e => e.type === 'collision' && e.ball === 0)?.other,
    cushions: run.events.filter(e => e.type === 'rail').length,
    duration: run.ticks * config.dt,
  };
}

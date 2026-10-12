import type { ShotInput, ShotSeed } from '../experiments/tailuge-lab/src/simulator';

/**
 * First hand-authored Chinese eight-ball practice bank.
 * Coordinates use Tailuge's table-centred metre space; ball index 0 is always
 * the cue ball. `seed` can be passed directly to new Simulator()/simulateShot().
 */
export type DrillKind = 'standard-break' | 'straight-pot' | 'thin-cut' | 'rail-pot' | 'one-cushion';

export interface PracticeDrill {
  readonly id: string;
  readonly kind: DrillKind;
  readonly title: string;
  readonly difficulty: 1 | 2 | 3 | 4 | 5;
  readonly objective: string;
  readonly suggestedCue: string;
  readonly seed: Readonly<ShotSeed>;
}

export const tailugeMvpLimits = Object.freeze({
  halfWidth: 2.54 / 2 - 0.028575,
  halfHeight: 1.27 / 2 - 0.028575,
  ballRadius: 0.028575,
  maxSpeed: 5,
  maxTipOffset: 0.451,
});

const rack = [
  [0.55, 0],
  [0.599624, -0.02865], [0.599624, 0.02865],
  [0.649248, -0.0573], [0.649248, 0], [0.649248, 0.0573],
  [0.698872, -0.08595], [0.698872, -0.02865], [0.698872, 0.02865], [0.698872, 0.08595],
  [0.748496, -0.1146], [0.748496, -0.0573], [0.748496, 0], [0.748496, 0.0573], [0.748496, 0.1146],
] as const;

function shot(balls: readonly { readonly x: number; readonly y: number }[], input: ShotInput): Readonly<ShotSeed> {
  return Object.freeze({ balls: balls.map((ball) => Object.freeze({ ...ball })), ...input });
}

export const zhongbaDrills: readonly PracticeDrill[] = Object.freeze([
  {
    id: 'zhongba-standard-break-v1',
    kind: 'standard-break',
    title: '标准开球',
    difficulty: 2,
    objective: '母球居中正击小三角顶球，观察首碰、散球与母球停位。',
    suggestedCue: '中杆，直线出杆；建议满力 88%，不加侧塞。',
    seed: shot([{ x: -0.85, y: 0 }, ...rack.map(([x, y]) => ({ x, y }))], { angle: 0, speed: 4.4, side: 0, top: 0 }),
  },
  {
    id: 'zhongba-straight-pot-v1',
    kind: 'straight-pot',
    title: '直球进袋',
    difficulty: 1,
    objective: '练习母球、目标球与右侧中袋方向的直线对准。',
    suggestedCue: '中低杆，轻中力；建议不加侧塞，注意母球撞后走位。',
    seed: shot([{ x: -0.60, y: 0 }, { x: 0.22, y: 0 }], { angle: 0, speed: 1.35, side: 0, top: -0.08 }),
  },
  {
    id: 'zhongba-thin-cut-v1',
    kind: 'thin-cut',
    title: '薄球切角',
    difficulty: 3,
    objective: '以薄切练习接触点和目标球向右上角袋的出球方向。',
    suggestedCue: '中杆偏低，轻中力；建议不加侧塞，先用理想接触点核对瞄准。',
    seed: shot([{ x: -0.60, y: -0.34 }, { x: 0.20, y: 0.02 }], { angle: 24.23, speed: 1.65, side: 0, top: -0.06 }),
  },
  {
    id: 'zhongba-rail-pot-v1',
    kind: 'rail-pot',
    title: '贴库目标球',
    difficulty: 4,
    objective: '目标球贴上库，练习薄切的容错和母球避开库边。',
    suggestedCue: '中杆，轻力；建议不加侧塞，先确认目标球并未落入袋口区域。',
    seed: shot([{ x: -0.58, y: 0.26 }, { x: 0.34, y: 0.56 }], { angle: 18.06, speed: 1.55, side: 0, top: 0 }),
  },
  {
    id: 'zhongba-one-cushion-v1',
    kind: 'one-cushion',
    title: '基础一库解球',
    difficulty: 3,
    objective: '先碰下库再接触目标球，比较理想反射提示与真实物理预测。',
    suggestedCue: '中杆，轻中力；建议零侧塞。多库提示仅用于选点，实际线路以物理预测为准。',
    seed: shot([{ x: -0.72, y: 0.30 }, { x: 0.28, y: 0.34 }, { x: -0.05, y: 0.03 }], { angle: -34.70, speed: 2.1, side: 0, top: 0 }),
  },
]);

export function validatePracticeDrill(drill: PracticeDrill): void {
  if (!/^[a-z0-9-]+-v\d+$/.test(drill.id)) throw new Error(`Invalid drill id: ${drill.id}`);
  if (!Number.isInteger(drill.difficulty) || drill.difficulty < 1 || drill.difficulty > 5) throw new Error(`${drill.id}: difficulty must be 1..5`);
  if (!drill.title.trim() || !drill.objective.trim() || !drill.suggestedCue.trim()) throw new Error(`${drill.id}: text fields are required`);
  const { balls, angle, speed, side, top } = drill.seed;
  if (balls.length < 2 || balls.length > 16) throw new Error(`${drill.id}: requires cue ball and 1..15 object balls`);
  if (![angle, speed, side, top].every(Number.isFinite) || speed < 0 || speed > tailugeMvpLimits.maxSpeed || Math.hypot(side, top) > tailugeMvpLimits.maxTipOffset) throw new Error(`${drill.id}: invalid ShotInput`);
  balls.forEach((ball, index) => {
    if (!Number.isFinite(ball.x) || !Number.isFinite(ball.y) || Math.abs(ball.x) > tailugeMvpLimits.halfWidth || Math.abs(ball.y) > tailugeMvpLimits.halfHeight) throw new Error(`${drill.id}: ball ${index} outside table`);
    balls.slice(0, index).forEach((other, otherIndex) => {
      if (Math.hypot(ball.x - other.x, ball.y - other.y) < 2 * tailugeMvpLimits.ballRadius) throw new Error(`${drill.id}: balls ${otherIndex} and ${index} overlap`);
    });
  });
}

export function validatePracticeBank(drills: readonly PracticeDrill[] = zhongbaDrills): void {
  const ids = new Set<string>();
  for (const drill of drills) {
    if (ids.has(drill.id)) throw new Error(`Duplicate drill id: ${drill.id}`);
    ids.add(drill.id);
    validatePracticeDrill(drill);
  }
}

validatePracticeBank();

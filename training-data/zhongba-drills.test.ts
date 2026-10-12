import { validatePracticeBank, validatePracticeDrill, zhongbaDrills } from './zhongba-drills';
import { Simulator } from '../experiments/tailuge-lab/src/simulator';

function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

function rejects(action: () => void, expected: string): void {
  try { action(); } catch (error) { check(String(error).includes(expected), `Expected ${expected}, got ${error}`); return; }
  throw new Error(`Expected validation failure: ${expected}`);
}

validatePracticeBank();
check(zhongbaDrills.length === 5, 'Expected five MVP drills');
check(new Set(zhongbaDrills.map((drill) => drill.kind)).size === 5, 'Expected every requested drill kind');
for (const drill of zhongbaDrills) {
  check(drill.seed.balls[0] !== undefined, `${drill.id}: cue ball missing`);
  check(Object.isFrozen(drill.seed), `${drill.id}: seed must be immutable`);
  validatePracticeDrill(drill);
  check(new Simulator(structuredClone(drill.seed)).tick === 0, `${drill.id}: seed must instantiate Tailuge Simulator`);
}
rejects(() => validatePracticeDrill({ ...zhongbaDrills[1], id: 'bad id' }), 'Invalid drill id');
rejects(() => validatePracticeDrill({ ...zhongbaDrills[1], seed: { ...zhongbaDrills[1].seed, balls: [{ x: 0, y: 0 }, { x: 0, y: 0 }] } }), 'overlap');
rejects(() => validatePracticeDrill({ ...zhongbaDrills[1], seed: { ...zhongbaDrills[1].seed, side: 0.451, top: 0.451 } }), 'invalid ShotInput');
console.log(`Training data checks passed: ${zhongbaDrills.length} drills`);

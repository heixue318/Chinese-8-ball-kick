import test from 'node:test';
import assert from 'node:assert/strict';
import { Simulator, predict, simulateShot, analyzeShot, scenarios, config } from '../dist/simulator.mjs';
for (const [key, {seed}] of Object.entries(scenarios)) test(`${key}: finite, settles, prediction equals separately stepped playback at every sample`, () => {
  const result = predict(seed), sim = new Simulator(structuredClone(seed));
  for (const frame of result.frames) { while (sim.tick < frame.tick) sim.step(); assert.deepEqual(sim.snapshot(), frame.balls); }
  assert.ok(sim.done); assert.ok(result.ticks < config.maxSeconds / config.dt); assert.deepEqual(sim.events, result.events);
});
test('sliding transitions to rolling, contact slip converges', () => {
  const r = predict(scenarios.slide.seed); assert.ok(r.events.some(e => e.type === 'Rolling'));
  assert.ok(r.frames.some(f => f.balls[0].state === 'Rolling' && f.balls[0].slip < .01));
});
test('head-on collision transfers forward motion to target', () => {
  const sim = new Simulator(scenarios.collision.seed); while (!sim.done && !sim.events.some(e => e.type === 'collision')) sim.step();
  assert.ok(sim.balls[1].vel.x > .5); assert.ok(sim.balls[1].vel.x > sim.balls[0].vel.x);
});
test('draw reverses cue ball after contact; follow continues forwards', () => {
  for (const [key, sign] of [['draw', -1], ['follow', 1]]) {
    const sim = new Simulator(scenarios[key].seed); while (!sim.done && !sim.events.some(e => e.type === 'collision')) sim.step();
    for (let i = 0; i < 180; i++) sim.step(); assert.ok(sign * sim.balls[0].vel.x > .1, key);
  }
});
test('side spin changes cushion exit velocity', () => {
  const results = ['rail', 'side'].map(k => { const sim = new Simulator(scenarios[k].seed); while (!sim.done && !sim.events.some(e => e.type === 'rail')) sim.step(); return sim.balls[0].vel.clone(); });
  assert.ok(results[0].distanceTo(results[1]) > .1);
});
test('center and corner pockets reach InPocket', () => {
  for (const key of ['pocket', 'corner']) { const r = predict(scenarios[key].seed); assert.ok(r.events.some(e => e.type === 'pot')); assert.equal(r.frames.at(-1).balls[0].state, 'InPocket'); }
});
test('invalid and overlapping inputs are rejected', () => {
  assert.throws(() => new Simulator({...scenarios.draw.seed, speed: NaN}));
  assert.throws(() => new Simulator({...scenarios.draw.seed, balls: [{x:0,y:0},{x:0,y:0}]}));
});
test('public question-bank interface produces a replayable outcome', () => {
  const input = structuredClone(scenarios.corner.seed);
  const run = simulateShot(input, 25);
  const outcome = analyzeShot(run);
  assert.equal(outcome.cuePotted, outcome.potted.includes(0));
  assert.deepEqual(outcome.potted, [...new Set(run.events.filter(event => event.type === 'pot').map(event => event.ball))]);
  assert.ok(outcome.duration > 0);
  assert.deepEqual(simulateShot(input, 25), run);
});

import { analyzeShot, simulateShot, type ShotSeed, type SimulationRun } from './simulator';
import { initialChineseEightBallProfile, type CalibrationProfile } from './calibration';
export { initialChineseEightBallProfile, joyCompetitionInitialProfile } from './calibration';

export type CalibrationMeasurement = Record<string, number | boolean | undefined>;
export type CalibrationScenario = {
  id: string;
  category: 'straight-roll' | 'head-on' | 'thin-cut' | 'one-cushion' | 'pocketing';
  name: string;
  purpose: string;
  seed: ShotSeed;
  measure: (run: SimulationRun) => CalibrationMeasurement;
  assert: (measurement: CalibrationMeasurement) => void;
};
const fail = (condition: boolean, message: string) => { if (!condition) throw new Error(message); };
const afterEvent = (run: SimulationRun, type: string) => { const event = run.events.find(item => item.type === type); return event && run.frames.find(frame => frame.tick >= event.tick); };
const potted = (run: SimulationRun) => analyzeShot(run).potted;

/** Five calibration categories; pocketing intentionally has center and bottom-pocket variants. */
export const calibrationScenarios: CalibrationScenario[] = [
  {
    id: 'straight-roll-distance', category: 'straight-roll', name: '直线滑行距离', purpose: '拟合台呢滚动摩擦；从录像读取停球中心与起点的距离。',
    seed: { balls: [{ x: -.75, y: 0 }], angle: 0, speed: .3, side: 0, top: 0 },
    measure: run => ({ distance: run.frames.at(-1)!.balls[0].pos[0] + .75, cushions: analyzeShot(run).cushions }),
    assert: measurement => { fail((measurement.distance as number) > .15, '直线球距离未前进'); fail(measurement.cushions === 0, '直线球不应碰库'); },
  },
  {
    id: 'head-on-collision', category: 'head-on', name: '正碰', purpose: '检查球球碰撞与速度转移；从录像读取两球碰撞后速度。',
    seed: { balls: [{ x: -.6, y: 0 }, { x: 0, y: 0 }], angle: 0, speed: 1.8, side: 0, top: 0 },
    measure: run => { const frame = afterEvent(run, 'collision')!; return { firstContact: analyzeShot(run).firstContact, targetSpeedX: frame.balls[1].vel[0], cueSpeedX: frame.balls[0].vel[0] }; },
    assert: measurement => { fail(measurement.firstContact === 1, '正碰的首次目标球错误'); fail((measurement.targetSpeedX as number) > (measurement.cueSpeedX as number), '正碰后目标球未取得主要速度'); },
  },
  {
    id: 'thin-cut', category: 'thin-cut', name: '薄碰', purpose: '检查切球角度与切向速度；从录像读取目标球碰撞后的横向速度。',
    seed: { balls: [{ x: -.64, y: -.06 }, { x: 0, y: 0 }], angle: 5.4, speed: 1.65, side: 0, top: 0 },
    measure: run => { const frame = afterEvent(run, 'collision')!; return { firstContact: analyzeShot(run).firstContact, targetSpeedY: frame.balls[1].vel[1] }; },
    assert: measurement => { fail(measurement.firstContact === 1, '薄碰未命中目标球'); fail(Math.abs(measurement.targetSpeedY as number) > .05, '薄碰没有可测的横向速度'); },
  },
  {
    id: 'one-cushion', category: 'one-cushion', name: '一库', purpose: '拟合库边反弹；从录像读取首次库边接触前后方向。',
    seed: { balls: [{ x: -.7, y: -.2 }], angle: 26, speed: .8, side: 0, top: 0 },
    measure: run => ({ cushions: analyzeShot(run).cushions, potted: potted(run).length > 0 }),
    assert: measurement => { fail((measurement.cushions as number) >= 1, '一库球未碰库'); fail(measurement.potted === false, '一库标定球不应进袋'); },
  },
  {
    id: 'center-pocket', category: 'pocketing', name: '中心袋入袋', purpose: '检查中袋开口；记录命中线、速度和是否入袋。',
    seed: { balls: [{ x: 0, y: .25 }], angle: 90, speed: 1, side: 0, top: 0 },
    measure: run => ({ potted: potted(run).includes(0) }),
    assert: measurement => fail(measurement.potted === true, '中心袋标定球未入袋'),
  },
  {
    id: 'bottom-pocket', category: 'pocketing', name: '底袋入袋', purpose: '检查角袋开口与袋角；记录命中线、速度和是否入袋。',
    seed: { balls: [{ x: -.9, y: -.28 }], angle: -138, speed: 1, side: 0, top: 0 },
    measure: run => ({ potted: potted(run).includes(0) }),
    assert: measurement => fail(measurement.potted === true, '底袋标定球未入袋'),
  },
];
export function runCalibrationScenario(scenario: CalibrationScenario, profile: CalibrationProfile = initialChineseEightBallProfile) {
  const run = simulateShot(scenario.seed, 10, profile); const measurement = scenario.measure(run); scenario.assert(measurement); return { scenario, run, measurement };
}

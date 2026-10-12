import { setR, setm, setmu, setmuS, setrho, setee, setμs, setμw } from '../vendor/tailuge/model/physics/constants';
import { TableGeometry } from '../vendor/tailuge/view/tablegeometry';
import { PocketGeometry } from '../vendor/tailuge/view/pocketgeometry';

/**
 * Complete, JSON-serializable input for a physical table profile.
 * Every numeric field is SI unless its field name ends with `Scale`.
 */
export type CalibrationProfile = {
  schemaVersion: 1;
  id: string;
  label: string;
  source: { kind: 'initial-estimate' | 'user-provided-initial' | 'measured'; note: string };
  units: { distance: 'm'; mass: 'kg'; time: 's'; angle: 'rad'; speed: 'm/s' };
  table: { playingLength: number; playingWidth: number };
  ball: { radius: number; mass: number };
  cloth: { rollingFriction: number; slidingFriction: number; spinDecay: number };
  cushion: { restitution: number; tableFriction: number; cushionFriction: number };
  pockets: {
    /** Runtime controls supported by the current simplified Tailuge pocket model. */
    openingScale: number;
    jawScale: number;
    /** Physical measurements are retained without pretending they map to one radius. */
    measurements: {
      railLipOpening: number | null;
      cornerClearPassage: number | null;
      middleClearPassage: number | null;
      tolerance: number | null;
      note: string;
    };
  };
  equipment: { cloth: string; cushion: string; reboundRelativeErrorTarget: number | null };
  simulation: { dt: number; maxSeconds: number };
};

/**
 * Reasonable 9 ft Chinese eight-ball starting estimate, not a real-table calibration.
 * Dimensions refer to the playing surface. Pocket and jaw values inherit Tailuge geometry.
 */
export const initialChineseEightBallProfile: CalibrationProfile = Object.freeze({
  schemaVersion: 1,
  id: 'cn8-9ft-initial-v1',
  label: '中式八球 9 尺初值',
  source: { kind: 'initial-estimate', note: '2.54 × 1.27 m 比赛台面、57.15 mm 球的工程初值；摩擦和库边参数来自 Tailuge 默认模型，未做实台拟合。' },
  units: { distance: 'm', mass: 'kg', time: 's', angle: 'rad', speed: 'm/s' },
  table: { playingLength: 2.54, playingWidth: 1.27 },
  ball: { radius: .028575, mass: .17 },
  cloth: { rollingFriction: .007, slidingFriction: .126, spinDecay: .045 },
  cushion: { restitution: .85, tableFriction: .2, cushionFriction: .175 },
  pockets: { openingScale: 1, jawScale: 1, measurements: { railLipOpening: null, cornerClearPassage: null, middleClearPassage: null, tolerance: null, note: '未测量；当前仅保留 Tailuge 按球半径缩放的袋口与袋角形状。' } },
  equipment: { cloth: '未标定', cushion: '未标定', reboundRelativeErrorTarget: null },
  simulation: { dt: 1 / 1000, maxSeconds: 40 },
} as CalibrationProfile);

/**
 * User-provided event-grade / JOY Chinese-eight-ball initial archive.
 * Measurements remain distinct because the current pocket model has only a global opening/jaw scale.
 */
export const joyCompetitionInitialProfile: CalibrationProfile = Object.freeze({
  ...initialChineseEightBallProfile,
  id: 'joy-competition-initial-user-v1',
  label: '乔氏/赛事级中八初始档案（用户提供）',
  source: { kind: 'user-provided-initial', note: '用户提供：口沿约 85 mm；角袋内沿最短可通过宽度 105 mm ±1 mm；腰袋约 120 mm。尚未针对单张实体球台拟合。' },
  pockets: {
    openingScale: 1,
    jawScale: 1,
    measurements: {
      railLipOpening: .085,
      cornerClearPassage: .105,
      middleClearPassage: .120,
      tolerance: .001,
      note: '85 mm 是口沿测量；105 mm 是角袋内沿最短可通过宽度；120 mm 是腰袋可通过宽度。三者不是同一个 radius。当前模型只使用 openingScale 与 jawScale，测量值仅存档，待定制袋角几何后映射。',
    },
  },
  equipment: { cloth: '赛事台高密羊毛呢', cushion: '进口高弹库胶 / 65 锰钢复合', reboundRelativeErrorTarget: .01 },
} as CalibrationProfile);

let activeProfile: CalibrationProfile = initialChineseEightBallProfile;
function finitePositive(value: number, name: string) { if (!Number.isFinite(value) || value <= 0) throw new Error(`Invalid calibration ${name}`); }
/** Applies a profile to Tailuge's module-level constants and table geometry. */
export function applyCalibrationProfile(profile: CalibrationProfile): CalibrationProfile {
  if (profile.schemaVersion !== 1) throw new Error(`Unsupported calibration schema: ${profile.schemaVersion}`);
  finitePositive(profile.table.playingLength, 'table.playingLength'); finitePositive(profile.table.playingWidth, 'table.playingWidth');
  finitePositive(profile.ball.radius, 'ball.radius'); finitePositive(profile.ball.mass, 'ball.mass'); finitePositive(profile.simulation.dt, 'simulation.dt'); finitePositive(profile.simulation.maxSeconds, 'simulation.maxSeconds');
  for (const [name, value] of Object.entries({ ...profile.cloth, ...profile.cushion, openingScale: profile.pockets.openingScale, jawScale: profile.pockets.jawScale })) finitePositive(value, name);
  for (const [name, value] of Object.entries(profile.pockets.measurements)) if (typeof value === 'number') finitePositive(value, `pockets.measurements.${name}`);
  if (profile.equipment.reboundRelativeErrorTarget !== null) finitePositive(profile.equipment.reboundRelativeErrorTarget, 'equipment.reboundRelativeErrorTarget');
  setR(profile.ball.radius); setm(profile.ball.mass); setmu(profile.cloth.rollingFriction); setmuS(profile.cloth.slidingFriction); setrho(profile.cloth.spinDecay);
  setee(profile.cushion.restitution); setμs(profile.cushion.tableFriction); setμw(profile.cushion.cushionFriction);
  TableGeometry.X = profile.table.playingLength / 2; TableGeometry.Y = profile.table.playingWidth / 2;
  TableGeometry.tableX = TableGeometry.X - profile.ball.radius; TableGeometry.tableY = TableGeometry.Y - profile.ball.radius; TableGeometry.hasPockets = true;
  PocketGeometry.scaleToRadius(profile.ball.radius);
  PocketGeometry.pocketCenters.forEach(pocket => { pocket.radius *= profile.pockets.openingScale; });
  PocketGeometry.knuckles.forEach(jaw => { jaw.radius *= profile.pockets.jawScale; });
  activeProfile = profile;
  return activeProfile;
}
export function getActiveCalibrationProfile(): CalibrationProfile { return activeProfile; }

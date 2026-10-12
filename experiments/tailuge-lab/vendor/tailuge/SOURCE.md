# Upstream source

Project: https://github.com/tailuge/billiards

Revision: `18bc11ae85c27a4e2f1c764f5467f82132aa1ab6`

License: GPL-3.0 (full text in `LICENSE`). Copyright remains with upstream contributors.

Copied from `src/model/ball.ts`, `src/model/physics/`, `src/view/tablegeometry.ts`, `src/view/pocketgeometry.ts`, `src/utils/three-utils.ts`, and selected functions from `src/utils/utils.ts`.

Changes: `model/ball.ts` removes rendering imports and DOM-based `BallMesh` construction; `utils/utils.ts` retains the numeric helpers used by physics and omits unrelated controller/UI helpers. The rest of this vendor snapshot follows the upstream revision. The local fixed-step scheduler lives outside the vendor tree at `src/simulator.ts`.

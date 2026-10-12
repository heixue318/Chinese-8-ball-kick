# Tailuge 训练适配契约与迁移清单

本文件为 `experiments/tailuge-lab` 的下一阶段准备，不修改其物理引擎、模拟器或页面。可执行类型草案在 `tools/tailuge-training-contract/training-contract.ts`。

## 目标边界

训练层保存球局、摆球、出杆控件、重打和复盘；它通过 `TrainingPhysicsAdapter` 调用 Tailuge 的真实 `predict`。训练层不实现第二套旋转、碰撞、袋角或反弹物理。

理想几何与真实预测必须分别传递和分别渲染：

| 输出 | 来源 | 允许表达 | 禁止表达 |
| --- | --- | --- | --- |
| `IdealGeometryHint` | 假想球与镜面反射计算 | 假想球、接触点、目标球进袋方向、最多 N 库的理想提示 | “预计落点”、旋转后的反弹、实际进球保证 |
| `PhysicsPrediction` | 相同 Tailuge 模型、标定和输入的 `predict` | 帧序列、碰撞/库边/袋口事件、真实预测线路 | 使用不同输入、不同标定或几何线补全物理帧 |

界面同时显示时，理想线必须带“理想几何提示”文字和独立配色；真实预测才可标为“物理预测”。不可以把多库理想线用于动画、复盘或结果判定。

## 数据映射

| 训练契约 | Tailuge 适配要求 |
| --- | --- |
| `TrainingTable` | 从 `config`、`TableGeometry`、`PocketGeometry` 创建只读快照；坐标明确为球台中心的米，`+y` 向上。记录 `calibrationId`。 |
| `TrainingLayout` | `id: 0` 是母球；对象球 id 在同一球型、预测、复盘中不变。适配 `Seed.balls` 前按 id 排序并拒绝非连续或无法表示的 id。 |
| `ShotControls` | 一一映射为 `Seed.angle/speed/side/top`；保存原始浮点值，不能在预测后只保存显示值。 |
| `PhysicsPrediction` | 使用从相同 layout/controls 生成的新 `Simulator` 并调用 `predict`；将 tick 转成秒并复制帧数据，不能返回 live `Ball` 或 `Vector3`。 |
| `ShotReview` | 出杆前快照为 `before`；每个采样帧来自实际执行的模拟器；停下后保存 `after`。复盘 seek 只读，不能回写正在显示的模拟器。 |

## 摆球、球型和重打

`validateLayout` 是摆球前置校验：母球必须存在且未入袋，id 不重复；未入袋球必须在球心活动区域内、不落在袋口中心区、不重叠。运动中应返回 `moving`，不应用自动吸附或静默移动球。

预设应通过 `DrillPreset` 标识及版本化布局数据存储。`straight`、`cut`、`one-cushion`、`two-cushion` 表示训练题型，不能承诺对应库数一定由真实预测实现。随机球型必须保存 `seed`、球数、表台 `calibrationId` 和随机算法版本；使用同一组合必须生成同一 layout。

点击重打时，将适配器恢复到 `before`，同时取消运行中的模拟、清除尚未完成的帧和临时事件。保留 `controls` 以恢复瞄准控件；下一次有效出杆开始新的复盘记录。

## 迁移顺序

1. 实现一个仅适配层，不改 `src/simulator.ts` 或 `src/page.ts`：把 Tailuge 的坐标、袋口中心、ball state 和输入转换为本契约。
2. 先用 `validateLayout` 接管自由摆球；补充转换后的袋口区域测试、边界球和 15 球密集布局测试。
3. 将四种预设和随机生成器接入训练状态。随机结果持久化 seed 与算法版本，加载时先校验 `calibrationId`。
4. 每次出杆以同一 layout/controls 创建真实预测，并用同一输入启动播放。记录帧必须在自动摆回母球等 UI 后处理前截取。
5. 加入重打和只读复盘。验证重打后 layout 与 `before` 深度相等，复盘 seek 不改变 live simulator。
6. 最后单独添加理想几何提示层。它仅消费静态 layout，绝不写入 `PhysicsPrediction` 或动画路径。

## 验收标准

- 相同 layout、controls、`modelId` 与 `calibrationId` 的预测可复现；任何一项改变均作新预测。
- 真实预测帧和动画从同一 Tailuge 输入产生，并保留碰撞、袋角、旋转等引擎结果。
- UI 中理想几何和物理预测有不同的类型、标签与绘制通道。
- 摆球拒绝结果明确可解释；随机球型可以用持久化 seed 再现；重打与复盘均不泄漏可变引擎对象。

## 验证命令

在仓库根目录运行：

```powershell
& '.\experiments\tailuge-lab\node_modules\.bin\tsc.cmd' --noEmit --strict --target ES2022 '.\tools\tailuge-training-contract\training-contract.ts'
node --test '.\tools\tailuge-training-contract\training-contract.test.mjs'
```

# 中式黑八物理验证台

独立的浏览器实验台，使用 [tailuge/billiards](https://github.com/tailuge/billiards) 的运动、球球碰撞、库边、袋角与落袋代码。上游版本固定在 `18bc11ae85c27a4e2f1c764f5467f82132aa1ab6`，来源文件见 `vendor/tailuge/`。这个目录没有接入 Android 正式界面。

## 运行

需要 Node.js 20+ 和 pnpm。首次运行：

```powershell
cd 'D:\Codex\Chinese 8-ball kick\experiments\tailuge-lab'
pnpm install
pnpm run build
pnpm run check
pnpm test
pnpm start
```

打开 <http://127.0.0.1:8791/>。页面提供自由练习、进袋、一库解球和小三角开球。可在台面空白处拖动瞄准、使用滑杆设置力度、在母球击点上直接点击设置侧塞和高低杆；自由练习可拖动任意球摆位。击球结束会显示进球、首次碰球、碰库数和用时，并支持“重打本杆”与“重置球局”。虚线参考轨迹和实球动画各自从同一局面创建 `Simulator`，然后都调用同一个 `step()`；没有用另一套几何反射公式画参考线。

`node --test` 覆盖全部八个场景的逐采样一致性、球球碰撞、滑转滚、跟进/回拉、侧塞改变出库方向、两种落袋以及公开接口的确定性回放。`pnpm run check` 执行 TypeScript 类型检查。

## 题库接口

`src/simulator.ts` 暴露不依赖页面的接口：

- `ShotSeed`：球位与一次出杆输入；`ShotInput` 是其中的方向、力度、侧塞、高低杆部分。
- `simulateShot(seed, stride)`：生成可序列化的 `SimulationRun`，包含采样帧、事件和总 tick。
- `analyzeShot(run)`：产生 `ShotOutcome`（进球、母球落袋、首次碰球、碰库次数、用时）。
- `Simulator`：面向实时动画的固定步长实例。`step()` 是预演与实球的唯一物理推进入口。

题库可持久化 `ShotSeed`，再以 `simulateShot` 预先定义目标或判分；播放器用同一 `ShotSeed` 实例化 `Simulator`。

## 模型边界

- 实验台尺寸为 2.54 × 1.27 m，球半径 28.575 mm，球重 0.17 kg；这些是当前固定实验参数。袋口、袋角仍从上游按球半径缩放，**尚未按中式黑八实台测量与标定**。
- 上游 `Ball` 删除了浏览器球网格构造；只保留球状态和运动代码。原有数学函数、碰撞、袋角、袋口、库边模型保留在 `vendor/tailuge/`。`Simulator` 是独立的固定 1 ms 步长调度器，并加了输入、数值和越界检查。它没有直接复用上游 `Table` 的渲染、会话和规则代码。
- 固定步长得到可重复结果，但仍是数值近似；没有模拟跳球、扎杆、杆头打滑或球台制造差异。示例场景用于验证计算链路，不能证明对实台落点的绝对精度。
- 上游使用 GPL-3.0 许可证，副本在 `vendor/tailuge/LICENSE`。若把这份源码或其衍生物编入正式分发应用，须先完成 GPL 合规评估；目前把它留在独立实验目录，避免无意影响 Android 发布包。

## 集成建议

1. 用现场球台数据标定袋口、库胶反弹、台呢滑动/滚动摩擦和球重，建立实拍与模拟落点对照集。
2. 把 `Seed` 和逐帧结果定义成平台无关协议；Android 可在 WebView 使用这套 TypeScript 核心，或移植相同数学模型到 Java/Kotlin。两条路线都应逐样本比对八个场景和真实球台数据。
3. 参考线用模拟器的 `predict(seed)`，击球动画用 `new Simulator(seed).step()`。输入坐标、力度、击点与版本参数必须完全一致；不要再调用正式 UI 当前的理想镜面反射线算法。
4. 接入前决定源码许可方案，并对 15 球密集碰撞、袋口极限擦边、球停在袋角等边界局面增加测试。

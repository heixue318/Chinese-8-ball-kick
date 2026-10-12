# 瞄准与训练模块集成说明

模块是纯 Java，不依赖 Android Canvas，也不依赖某个物理引擎的数据类型。当前页面尚未接入，由总控整合 UI，避免并行修改 PracticeView。

## 文件与接口

- `TrainingModel`：不可变 Point/Ball/Table/Layout/Shot；母球 id 固定为 0。所有坐标采用引擎台面单位。当前引擎的台面是 2×1、半径 .022。
- `AimGeometry.potAim(table, layout, targetId, pocketIndex)`：目标球到袋口中心方向、假想母球中心、球面接触点、出杆方向、切球角，以及台内可达性/两段线路遮挡检查。不可达时仍返回几何信息，供界面画警示。重合点等退化输入抛出异常。
- `AimGeometry.trace(table, layout, heading, maxCushions)`：当前方向最多 0–32 次理想反射；返回连续线段，首次球碰撞或进入圆形袋口范围就停止。ghost 是碰撞时母球中心，contact 是球面接触点。objectDirection 为目标球单位方向；cueSeparation 是等质量无旋转碰撞的剩余速度向量，正碰为零，画线前不要强制归一化零向量。几何角点同时反转两个方向，计为一次反射事件。
- `TrainingSession`：自由摆球、四个预设、可复现随机球型、重打、实际运行快照复盘。
- `PracticeTrainingAdapter`：连接现有 PracticePhysics；restore 重置全部运动内部状态，保留累计出杆次数，保证母球排在索引 0。不同引擎只需实现 TrainingModel.Engine。

## 页面接入顺序

1. 在现有 sim 上创建 `PracticeTrainingAdapter adapter` 和 `TrainingSession training`。
2. 绘制辅助线时获取 `adapter.snapshot()`，调用 trace；另外由用户选定目标球与袋口后调用 potAim。辅助线应标为“理想几何”，不宣称真实旋转预测。
3. 摆球统一调用 `training.place(id, new Point(x,y))`。越界、袋口内、重叠、运动中均返回 false，不自动夹取到边缘。球型切换调用 `training.load(TrainingSession.preset(adapter.table(), preset))` 或 `random(table, count, seed)`。预设是训练起始布局，并不保证自动解出一库或两库。
4. 出杆统一调用 `training.shoot(new Shot(...))`，仅成功后启动动画时钟；保存当前杆的 elapsed=0。运动步骤累计模拟时间，调用 `training.capture(elapsed)`，最后一帧必须在 `sim.respotCue()` 前采集。避免混用旧的 sim.shoot/restore/place：旧入口不会更新训练历史。
5. 重打调用 `training.retry()`，恢复出杆前的布局并取消当前动画；视图仍需清空自己的 previous/accumulator。`lastShot()` 可恢复方向、力度、击点、杆角控件。重打后的下一次 shoot 开始新记录。
6. 本杆停止后 `training.review()` 返回不可变 before/after/shot/frames；`review.at(seconds)` 返回不晚于指定时间的已录制帧，供独立复盘绘制。它不会改动实时引擎。每秒最多约 30 帧，达到 1800 帧时抽稀旧帧，保留起始和最终球局。当前仅保留最近一杆，不包含跨进程保存。

## 几何边界

参考 https://github.com/lecepin/billiard-aim-calculation 的假想球可视化表达，自行实现几何算法，没有移植其页面代码或把它当物理引擎。假想球中心 = 目标球中心 − 2R×入袋单位方向，接触点 = 目标球中心 − R×入袋单位方向。

多库采用理想矩形球心边界反射，圆形袋口捕获近似；不计算袋角、球碰撞抛掷、侧旋、跟进/回拉、摩擦或多球连续碰撞。进球线连接袋口中心，仅用于训练参考。复盘使用适配器提供的真实引擎运行快照，与理想辅助线严格区分。

## 验证

运行 `./tools/test-training.ps1`。覆盖假想球/接触点、正碰零分离、切球垂直分离、遮挡与反面瞄准、多库、贴库和角点、袋口终止、全部预设、100 个随机满台种子、确定性、摆球拒绝、快照隔离、运动中重打及复盘无副作用。

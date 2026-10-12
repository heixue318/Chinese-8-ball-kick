# 中八练习球型数据

`zhongba-drills.ts` 是第一批可直接传入 Tailuge `ShotSeed`/`ShotInput` 的练习题库。每个 `seed` 的 `balls[0]` 是母球，后续元素是稳定顺序的目标球；坐标采用 Tailuge 的球台中心米制坐标。

当前数据包含标准开球、直球、薄球、贴库目标球和基础一库。难度与说明服务训练编排，不承诺该建议杆法一定进球：特别是一库题的镜面反射只能作为“理想几何提示”，实际结果应由相同 `ShotSeed` 运行 `simulateShot` 后判定。

假想球、接触点和目标球入袋方向可采用 [lecepin/billiard-aim-calculation](https://github.com/lecepin/billiard-aim-calculation) 的教学表达作视觉参考；本题库不复制其代码。该参考不含射线终止、袋口/库边处理或连续物理，且上游仓库未见许可证，因此它只可生成 `IdealGeometryHint`，不得替代或混入 Tailuge 的 `PhysicsPrediction`。

运行 `./tools/test-training-data.ps1` 以编译类型并验证所有题目、边界、重叠、杆法输入和题目唯一性。

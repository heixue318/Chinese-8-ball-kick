# 中八解球

中式黑 8 解球练习工具。目前仓库同时保留原生 Android 原型、Flutter 界面参考工程，以及以 Tailuge 物理核心驱动的 Web 练习 MVP。

## 推荐试用版本

\`experiments/tailuge-lab\` 是当前推荐继续开发的版本。它的预演轨迹和实球动画共用同一套固定步长模拟器，已支持自由摆球、瞄准、力度、击点、杆角、进袋、重打和重置。

\`\`\`powershell
Set-Location experiments/tailuge-lab
node build.mjs
node server.mjs
\`\`\`

然后访问 \`http://127.0.0.1:8791/\`。验证命令：

\`\`\`powershell
node node_modules/typescript/bin/tsc --noEmit
node --test test/*.test.mjs
\`\`\`

该 MVP 复用了 [tailuge/billiards](https://github.com/tailuge/billiards) 的物理代码，完整来源和上游提交记录在 \`experiments/tailuge-lab/vendor/tailuge/SOURCE.md\`；项目按 GPL-3.0 发布，详见根目录 [LICENSE](LICENSE)。

## 原生 Android 原型

中式黑 8 解球练习工具，当前本地 Android 版本为 **0.3.0**，固定横屏显示。

## 功能

- 自由练习：拖动台面瞄准，显示球杆、第一碰撞点、目标球方向和最多两次库边反射。
- 左侧拉杆：向下拖动蓄力，松手击球；“击球”按钮使用当前力度。
- 右侧控制：拖动母球红点设置击点，调整 0–60° 杆角，并拖动竖向微调器调整方向。
- 摆球模式：自由拖动母球和目标球，禁止球体重叠；支持解球球局和十五球球局。
- 连续击球动画：球体碰撞、库边反弹、减速、六袋判定；母球入袋后重新摆放。
- 重试本杆：恢复上一杆出杆前的球局，球体运动中也可以取消并恢复。
- 设置：查看使用帮助、检查 GitHub 上的新版本。
- AR 解球入口目前会提示相机识别模块尚未接入。

## 构建

使用 Android Studio 打开项目，安装 Java 17、Android SDK Platform 35、Build Tools 35.0.0 和 Gradle 8.9 后运行 `app` 配置。本机工具安装在 `.tools/`，不提交到 Git。命令行构建与检查：

```powershell
./tools/build.ps1
./tools/test-physics.ps1
```

APK 输出在 `app/build/outputs/apk/debug/app-debug.apk`。

## 当前限制

- 采用二维近似物理。击点对首次碰撞后的跟进/回拉和库边侧旋有近似影响；杆角影响平面速度，不模拟跳球、扎杆、真实滑动转滚动或袋口袋角几何。不能作为真实球台的精确解球预测。
- 辅助线按照理想几何反射绘制，不包含旋转、减速和后续连续碰撞。
- AR 识别、透视校正、球体识别及现场校准尚未接入。
- 发布新版时需更新 `update.json` 并附上同版本 Android APK。
- 当前 `update.json` 仍指向已发布的 0.2.0；0.3.0 为本地测试版，尚未发布到 GitHub。

参考软件分析和取舍见 [docs/reference-analysis.md](docs/reference-analysis.md)。

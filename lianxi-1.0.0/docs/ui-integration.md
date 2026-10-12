# 练习界面集成边界

本次沿用 Flutter 首页、自由练习、设置和音效，不替换物理引擎。

- `ui/practice_input.dart`：力度、微调、加塞仅依赖此接口。现有 BilliardsGame 实现接口，后续引擎可提供自己的适配器。适配器负责运动中拒绝输入及 notifier 生命周期。向量沿用 Flame 的 Vector2，不依赖 Forge2D。
- `ui/practice_frame.dart`：供新渲染层使用的只读球位、击球参数和轨迹快照协议。台面坐标以米表示，x 向右、y 向下；轨迹由引擎提供。尚未替换现有 GameWidget 渲染，最终转换由总控与物理分支接入。
- 杆角控件通过值和回调连接；页面读取实际 cueElevationDegrees，消除重复状态。
- 首页、顶部按钮、设置、音效继续沿用现有实现。GameScreen 的导航、重打、球型与 GameWidget 仍是现有引擎的组合入口；本次没有宣称整个页面已完全解耦。
- 音效已有集中 AudioManager 与 GameSettings 开关/音量；后续引擎应把击球、碰撞、碰库、落袋事件转发至该模块。设置当前仅保存在内存。

## 验证

首页与原有规则/摆球检查 13 项通过；输入控件 4 项通过（独立接口替身、微调禁用、回零取消、松手出杆、取消触摸）。截图为 Flutter widget 测试真实渲染的控件图，位于 `test/goldens/practice-input-controls.png`；不代表新物理引擎的整页截图。

Windows 本机 SDK 路径包含空格，objective_c 原生资源钩子会失败。测试可在同一个 PowerShell 进程映射临时盘符后执行：

```powershell
subst U: 'D:\Codex\Chinese 8-ball kick'
Set-Location U:\lianxi-1.0.0
U:\.tools\flutter\bin\flutter.bat test --no-pub test/power_gauge_gesture_test.dart test/widget_test.dart
```

本次没有发布 APK 或提交 Git，供总控按上述文件集成。

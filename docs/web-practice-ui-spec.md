# Tailuge Web 练习界面迁移规格

本文只定义 Web 练习 MVP 的展示与交互边界。物理核心、轨迹求解、训练题库和 Tailuge 实验目录均不在此变更范围内。

## 页面骨架与层级

练习页固定以横屏为主，适配 16:9 到约 2:1 的可视区域。台面保持其物理宽高比，所有控件置于台面外围或台面顶层；不以 CSS 尺寸参与物理坐标计算。

```text
PracticePage
├─ TableViewport                 z: 0   背景、球桌、球、球杆
├─ PredictionOverlay             z: 1   引擎返回的预测轨迹、接触点、警示
├─ TableInputLayer               z: 2   台面瞄准/摆球手势
├─ HeaderToolbar                 z: 10  返回、模式、收球区、工具按钮
├─ LeftPowerControl              z: 10  竖向力度条
├─ RightFineAimControl           z: 10  竖向微调轮
├─ RightParameterControls        z: 10  加塞、杆角入口
└─ ModalLayer                    z: 20  加塞、杆角、球型、设置对话框
```

`ModalLayer` 打开时拦截所有其他指针事件。球在运动中仍可显示工具栏和收球区，但所有会改变出杆或球局的控件显示禁用状态。

## 引擎输入与输出边界

界面只消费以下快照，不调用 Tailuge 的内部对象：

```ts
type Vec2 = { x: number; y: number };

type PracticeShot = {
  directionRadians: number;
  power: number;             // 0..1
  spin: Vec2;                // 单位圆内；+y 为低杆
  elevationDegrees: number;  // 0..90，MVP 可先只展示/透传
};

type PracticeFrame = {
  moving: boolean;
  balls: ReadonlyArray<{ id: number; position: Vec2; pocketed: boolean }>;
  trajectories: ReadonlyArray<ReadonlyArray<Vec2>>;
  shot: PracticeShot;
};

type PracticeCommands = {
  setAim(directionRadians: number): void;
  setPower(power: number): void;
  setSpin(spin: Vec2): void;
  setElevation(elevationDegrees: number): void;
  shoot(): Promise<void>;
  toggleGuideline(): void;
  resetLayout(): void;
  retryLastShot(): void;
  loadPreset(id: string): void;
};
```

引擎发布 `PracticeFrame` 后，Web 端统一换算台面坐标到 `TableViewport`。轨迹为引擎同一模拟器输出的 polyline，页面不可再用镜面反射重算。`moving === true` 时命令层应拒绝 `setAim`、`setPower`、`setSpin`、`setElevation` 与 `shoot`，界面以禁用态提示，避免仅靠前端状态造成竞态。

## 组件映射与交互状态

| 现有交互 | Web 组件 | 状态 | 指针行为 | 引擎命令 |
| --- | --- | --- | --- | --- |
| 瞄准微调轮 | `FineAimControl` | `aimAngle`, `enabled`, `dragOriginY` | 在轮内上下拖动；每移动 1 px 改变固定小角度，松手保持 | `setAim(aimAngle)` |
| 力度条 | `PowerControl` | `power`, `dragStartY`, `armed` | 按下归零；向下拖动增加力度；松手在 `power >= 0.015` 时出杆；回到起点或取消归零 | `setPower(power)`, `shoot()` |
| 母球加塞 | `SpinControl` + `SpinDialog` | `spin`, `open` | 点击入口开弹层；在母球圆盘内拖红点，超圆形范围投影到圆边；“居中”归零 | `setSpin(spin)` |
| 杆角 | `ElevationControl` + `ElevationDialog` | `elevationDegrees`, `open` | 点击入口开弹层；垂直拖动或滑块设定 0–90°；“水平”设 0° | `setElevation(value)` |
| 顶部工具栏 | `HeaderToolbar` | `guidelineVisible`, `canRetry`, `presetOpen` | 返回、辅助线、设置、重打、球型、重置；每个按钮独立可访问 | 对应工具命令/路由 |
| 收球区 | `PocketedBallTray` | `pocketedBallIds` | 仅展示，不接收手势；窄屏超出时以 `+N` 合并 | 由 frame/规则快照提供 |

所有控件可从最新 `PracticeFrame.shot` 回填，供重打、复盘或外部状态恢复。微调轮只保存当前角度，不把累计拖动距离作为业务状态。

## 横屏触控与响应式规则

以 CSS px 为准，交互目标最小 **48 × 48 px**；相邻独立目标间留至少 **8 px**。这是本项目手机横屏的下限，视觉图标可以更小，但透明点击区域必须满足该尺寸。

| 区域 | 宽高/间距 | 位置规则 |
| --- | --- | --- |
| 顶栏工具按钮 | 48 × 48 px，间隔 8 px | 台面上沿内侧，避开左/右控件区域 |
| 力度条点击带 | 宽 56–72 px，高至少 240 px | 左侧，距安全边距至少 12 px |
| 微调轮点击带 | 宽 56–72 px，高至少 240 px | 右侧，距安全边距至少 12 px |
| 加塞/杆角入口 | 各 48 × 48 px，间隔 8 px | 右上，位于微调轮上方 |
| 台面手势区 | 不小于可用空间的中心区域 | 控件点击带不得覆盖 |
| 弹层操作区 | 宽 `min(420px, calc(100vw - 32px))` | 居中，背景遮罩，内部主要拖动区至少 192 × 192 px |

建议以 `ResizeObserver` 计算 `TableViewport`，将左右控制带和顶部栏从可用宽高中预留；当有效高度低于 360 px 时：隐藏文字标签，仅保留 tooltip/无障碍名称；收球区改为 `+N`；不缩小触控目标。有效高度再低时显示“请旋转设备”的覆盖层，而不是把控件压到不可操作。

触摸事件使用 Pointer Events，并在控件拖动区域设置 `touch-action: none`，防止浏览器滚动或双指缩放夺取手势。每个图标按钮提供 `aria-label`，滑条/微调轮提供键盘等价操作（方向键微调，Home/End 归零/最大）。

## 视觉状态

- 可击球：控件保持深色金属底、金色/浅色高亮；力度条显示当前百分比。
- 球运动：所有击球参数灰化并禁用，保留轨迹和收球区更新；不弹出阻塞提示。
- 预测不可用：辅助线入口可保留，但轨迹层显示简短“预测暂不可用”，不得显示旧轨迹冒充当前结果。
- 物理拒绝命令：撤销控件临时状态，回填最近的 `PracticeFrame.shot`，以非阻塞 toast 说明原因。
- 设置的音效开关与音量只影响 Web 音频适配层；物理事件以 `cueHit`、`ballCollision`、`cushionHit`、`ballPocketed`、`foul` 事件名转发，UI 不从球位置推断音效。

## 实施顺序

1. 在 Web 应用建立 `PracticePage`、上述 TypeScript 协议和静态假数据，完成横屏布局与可访问性测试。
2. 将 Tailuge MVP 包装成 `PracticeFrame`/`PracticeCommands` 适配器，先接入球、运动状态、击球和同源预测轨迹。
3. 接入微调、力度、加塞与杆角，逐项验证“运动中禁用”和物理拒绝后的回填。
4. 最后接入训练题库、重打、球型和设置/音效事件；这些功能不应改变物理核心的状态模型。

## 验收清单

- 960 × 432 与 1280 × 720 横屏中，所有主要触控目标仍至少 48 px，彼此没有重叠。
- 力度拖到正值后松手仅调用一次 `shoot()`；回零或取消不出杆。
- 微调、加塞、杆角每次输入都经命令层传递，运动中无法修改。
- 预测轨迹来自与实球动画相同的引擎快照和参数；界面不生成第二套轨迹算法。
- 弹层打开时，台面与其他控件不响应指针；关闭后恢复上一次有效参数。
- 键盘、屏幕阅读器和触摸三种方式均能完成出杆与重置。

# 中八解球 Android

中式黑 8 解球练习工具，当前 Android 版本为 **0.2.0**，固定横屏显示。

## 功能

- 自由练习：摆放母球和目标球，显示母球到目标球的虚线及目标球延长线。
- 底部控制区：在白球上点选或拖动红点设置母球击点，调节 0–90° 球杆角度和击球力度，按下击球。
- 设置：查看使用帮助、检查 GitHub 上的新版本。
- AR 解球入口目前会提示相机识别模块尚未接入。

## 构建

使用 Android Studio 打开项目，安装 Android SDK Platform 35 后运行 `app` 配置。命令行构建：

```powershell
gradle assembleDebug
```

APK 输出在 `app/build/outputs/apk/debug/app-debug.apk`。

## 当前限制

- 球路是二维练习演示，击球动画、旋转、碰撞、库边反弹和袋口判定尚未构成经过标定的真实物理模型。
- AR 识别、透视校正、球体识别及现场校准尚未接入。
- 发布新版时需更新 `update.json` 并附上同版本 Android APK。

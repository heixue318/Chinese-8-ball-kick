# 0.3.0 本地测试记录

测试日期：2026-10-11（Asia/Shanghai）。测试包：`releases/zhongbaijieshu-0.3.0-preview.apk`，包名 `com.zhongbaijieshu.app`，版本代码 4。使用 Android 默认调试签名，尚未发布到 GitHub。`update.json` 保持指向已发布版本。

## 环境

Java 17、Gradle 8.9、Android SDK Platform 35、Build Tools 35.0.0、adb 和 Android 模拟器已安装在项目 `.tools/` 下。Android 11（API 30）Google APIs x86_64 镜像，1080 × 1920 屏幕，横屏运行。命令行工具位于 `.tools/android/cmdline-tools/latest/`。

## 结果

- `tools/test-physics.ps1`：通过碰撞、停止、恢复球局、禁止重叠摆球、母球入袋重摆、库边反弹、8 号球居中、十五球阵型与最大力度开球测试。
- `assembleDebug lintDebug`：构建成功，lint 0 个错误。剩余两个提醒涉及现有固定横屏和 Android 12 备份策略。
- `apksigner verify --verbose`：签名验证通过（v1、v2）。
- `tools/qa-practice.py`：在模拟器中实际操作通过。母球拖动只改变母球；瞄准和拉杆松手出杆可用；出杆后立即重试恢复所有球的位置；十五球有 16 个球，开球能够停止，重试能恢复全阵；辅助线开关、竖向微调、设置和帮助可用。
- 应用崩溃缓冲区没有 `com.zhongbaijieshu.app` 崩溃记录。
- 页面截图见 `docs/free-practice.png`，控件和球的位置由 Android 可访问性树提供给测试脚本。

## 参考软件运行观察

Billiards City 3.0.51 已安装并运行到练习教程。可以观察实体球杆、目标球碰撞处空心球预览、目标球方向及右侧竖向瞄准微调器。本项目据此重建相关操作。参考软件的 Cocos2d 页面没有暴露细分的可访问性控件，因此没有以坐标猜测来完成整套教程或宣称已复刻全部操作手感。

## 范围

测试覆盖 Android 11 模拟器；尚未进行真实手机和真实球台校准。物理参数和旋转效果为近似实现，辅助线不包含真实旋转、袋角或复杂连续碰撞。没有接入关卡地图、星级、奖励或解锁流程。

APK SHA256：`D8683A7422824CA6E5A7EB8DA58B179420F8C99195300FE9ADCCD8E60710119C`

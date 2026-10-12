# 自由练习界面预览

本次基于朋友提供的 Flutter 源码修改。截图来自真实运行的 Flutter Web 页面，横屏检查尺寸为 1280×720 与 960×432。

- 首页：虚化球房图片、暗色遮罩、自由练习主入口。
- 练习：左侧拖动微调瞄准；右上母球加塞；其下杆角；右侧长力度条。
- 加塞框：拖动红色击点、重置至中心，使用原有加塞状态与击球接口。
- 杆角框：拖动球杆、实时角度、恢复水平。当前为界面状态，尚未接入抬杆及跳球物理。
- 力度条：下拉增加力度，松手调用原有击球；回到拖动起点或更高处则归零取消。

验证：Web release 编译成功；本次修改的 5 个 Dart 文件静态分析无问题。浏览器确认加塞移动与重置、杆角调整至 34° 与重置、微调瞄准、零力度释放不击球、正力度释放击球；未出现浏览器运行错误。两个横屏尺寸均未见控件溢出。

截图：`home.jpg`、`practice.jpg`、`spin.jpg`、`angle.jpg`。

首页背景为本次生成的原创图片，位置：`assets/images/billiards-room.png`。
生成描述：Photorealistic refined billiards hall, emerald tables, walnut frames, warm pendant lights, dark room, no text, no logos, no people. Wide landscape composition suitable for a softly blurred app home background.

预览入口：本机服务运行时打开 http://127.0.0.1:8765/ 。

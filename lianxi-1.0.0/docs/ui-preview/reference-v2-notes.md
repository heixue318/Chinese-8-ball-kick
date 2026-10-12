# 第二版界面

按用户两张附件重做自由练习页面：左侧力度条、右侧微调轮，上方分别为杆角与母球加塞入口，球桌上方右侧为辅助线、设置、撤销、阵型和重摆按钮。首页中文名称为中八解球，移除英文，按手机阅读需求增大文字。

新增图片位于 `assets/images/`：table-skin、aim-wheel、power-track、power-handle、floor-texture、cue-skin、ball-0、ball-9、ball-10、ball-11。均按用户参考生成，透明材质在代码中按主体范围绘制。

图片设计依据：严格顶视角、偏橄榄绿台呢、红棕木边、银色袋口及角盖、暗灰金属轨道与银色活动滑块；木色细球杆、红棕握把和蓝色杆头；暖白高光与下缘暗部的球体。

新运行截图：`home-v2.jpg`、`practice-reference-v2.jpg`。手机截图：`home-mobile-v2.jpg`、`practice-reference-mobile-v2.jpg`。详细对照与验证见项目根目录 `design-qa.md`。

本轮将练习默认阵型设成参考图的三球局；可使用顶部阵型按钮切换其他练习。外观球径也用于现有碰撞模型，因此需在后续物理标定时进一步检查真实中式台球尺寸与袋口难度。

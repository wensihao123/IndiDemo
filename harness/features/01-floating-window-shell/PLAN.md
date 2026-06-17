---
artifact: PLAN
feature: 01-floating-window-shell
role: Planner
status: draft
updated: 2026-06-17
inputs: [FEATURE-DESIGN.md, project-context.md, ACCEPTANCE.md, project.godot(实测空项目)]
next: Implementer
---

# PLAN — 悬浮窗外壳 (Floating Window Shell)

## 1. Goal / 目标(一句话)
做出一个常驻主显示器底部、全屏宽、坐在任务栏之上的悬浮窗:内含 800×250 居中主区(两侧
占位背景平铺)、一个待机微动的占位战士,可一键平滑收起为屏幕角落的小 handle 再唤回,
置顶可切换——交付"桌面上一个活着的小队伙伴"的最小切片。

## 2. Approach & key decisions / 方案与关键决策
> 每条:做什么 + 为什么 + 否决的替代方案。

- **D1 主窗口即悬浮窗(不另开 Window 节点)。** Godot 项目的主窗口本身配成无边框、置顶,
  运行时用 `DisplayServer` 定位到屏幕底部。
  *为什么:* 一个 OS 窗口最简、无多窗口焦点/层级问题。
  *否决:* 主体 + handle 用两个独立 OS 窗口——焦点、置顶、生命周期都要各管一套,过度复杂。

- **D2 定位用工作区矩形 `screen_get_usable_rect()`,不用整屏 `screen_get_size()`。** 它返回
  **排除任务栏后的工作区**;把窗口贴其底边即自动"坐在任务栏之上、不重叠"。
  *为什么:* 直接满足 §3 F2(贴任务栏上沿不重叠),不必硬编码任务栏高度。
  *否决:* 用整屏高减去猜测的任务栏高——任务栏高度/位置因人而异,易错位。
  > ⚠ 需在目标机实测确认 usable_rect 确实避开了任务栏(见 Flags R3)。

- **D3 收起 = 把整个 OS 窗口用 Tween 收成角落小窗(约 64×64),展开 = 还原全宽×250。**
  收起/展开都对窗口 rect 做 ~0.25s 缓动,产生"滑动"观感;内容按状态切显示(展开显主区+
  背景+角色,收起只显 handle 图标)。
  *为什么:* §3 要求"收起态不遮挡任何东西"——必须真正释放屏幕空间,只能改 OS 窗口几何;
  单窗口缩到角落最简且满足"handle 常驻边缘从不消失"。
  *否决:* 窗口几何不变、只在内部滑动内容——收起后那条 250px 满宽窗仍占着屏幕底部,违反
  "不遮挡"。*否决:* 透明窗+点击穿透做悬浮——§6 已明确砍掉,且需平台特性,留后。
  > ⚠ 逐帧 `DisplayServer.window_set_position/size` 在 Windows 上可能略卡;0.25s 内可接受,
  > 若实测明显抖动,退路是"瞬切几何 + 仅内容做滑动缓动"(见 Flags R1)。

- **D4 占位角色"待机微动"用 `AnimationPlayer` autoplay 循环动 position.y/scale/modulate,
  不出帧序列。** 遵 STYLE-BIBLE §6 / ASSET-SPEC(单张静态 PNG,动画在运行时)。呼吸≈轻微
  上下浮 + 极小缩放。
  *为什么:* 美术只交付单张 128×160,微动是 game-feel 层;AnimationPlayer 可视化好调。
  *否决:* 多帧 sprite 动画——美术未交付帧序列,且违反"单张静态"约定。

- **D5 渲染模式从 Forward+ 切到 **Compatibility**,不启用 3D 物理。**
  *为什么:* 这是个常驻后台的 2D 桌面小挂件,要尽量省 CPU/GPU(服务支柱 1"不打扰");
  Compatibility 最轻、桌面兼容最广,2D 完全够用。
  *否决:* 保留 Forward+(为 3D/高级 2D 光照设计,这里纯属浪费);Mobile(介于两者,
  对纯桌面 2D 无收益)。
  > 渲染模式/导入预设本属 Engine Integrator,这里给出决策与理由,落项目设置由 EI 或
  > Implementer 执行(见 Flags R4)。

- **D6 帧率封顶(`Engine.max_fps`,展开态 ~60 / 收起态 ~10–15)。**
  *为什么:* 挂机小挂件长期常驻,不该满帧空转烧电;收起后几乎不动可进一步降。
  *否决:* 不限帧——后台空转吃资源,直接违反"伙伴不打扰"的支柱。

- **D7 布局用固定像素 + 锚点,stretch mode = `disabled`。** 背景 `TextureRect` 满铺(平铺
  模式)垫底;主区 `Control` 固定 800×250、水平居中(锚点居中,offset ±400);窗高恒 250。
  *为什么:* 屏宽随显示器变,但主区必须恒 800×250 不拉伸(§3);disabled 保证 1:1 像素、
  靠锚点摆放。
  *否决:* stretch `canvas_items` 整体缩放——会把 800 主区也按屏宽缩放,违反"主区固定"。

- **D8 收起/展开切换入口:展开态一个小"收起"按钮 + 收起态点 handle 唤回;置顶切换走
  快捷键(默认 F2)。** 切换收起也额外绑一个快捷键(默认 F1)。
  *为什么:* 窗口常不在焦点,纯靠键盘不可靠;点按 handle/按钮是"在焦点时一定可用"的主路径,
  快捷键作补充。
  *否决:* 只用全局快捷键——Godot 无内建全局热键(仅焦点时收输入),实现要 OS 级注册/插件,
  撞 hard-NO(不引插件),故全局热键留后(见 Flags R2)。

## 3. Ordered steps / 有序步骤
> 每步:动作 + 触及文件 + 如何验证。每步只依赖更早的步骤。

1. **项目设置打底(窗口/渲染/输入/主场景)。**
   - 动作:`project.godot` 设
     `display/window/size/mode=0`(windowed)、`borderless=true`、`always_on_top=true`、
     `transparent=false`、`stretch/mode="disabled"`;视口 `viewport_width=1280 height=250`
     (运行时会按屏覆盖);渲染 `rendering/renderer/rendering_method="gl_compatibility"`
     (D5);新增 InputMap 动作 `toggle_collapse`(默认 F1)、`toggle_always_on_top`(默认 F2)。
     主场景设为 step 2 的 `floating_shell.tscn`。
   - 文件:`project.godot`。
   - 验证:`godot --headless --check-only` 无报错;编辑器打开项目无渲染/解析报错。

2. **主场景骨架 + 运行时贴底定位。**
   - 动作:建 `scenes/shell/floating_shell.tscn`,根 `Control`(full rect)挂
     `src/shell/floating_shell.gd`。`_ready()` 里用 D2:
     取 `var ur = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())`,
     `window_set_size(Vector2i(ur.size.x, 250))`,
     `window_set_position(Vector2i(ur.position.x, ur.end.y - 250))`。
   - 文件:`scenes/shell/floating_shell.tscn`、`src/shell/floating_shell.gd`。
   - 验证:Play → 屏幕最底部出现一条全屏宽、250px 高的窗,**底边贴任务栏上沿、不重叠**,
     不盖任务栏。

3. **背景平铺 + 800×250 居中主区。**
   - 动作:加 `BgStrip`(`TextureRect`,锚点 full rect,`stretch_mode = STRETCH_TILE`,
     贴 `bg_strip_placeholder.png`)垫在最底;加 `MainArea`(`Control`,锚点水平居中、
     高占满 250,offset_left=-400/right=+400 → 恒 800 宽)。窄屏兜底(D7/R5):屏宽<800 时
     `MainArea.scale = min(1.0, width/800.0)` 并保持居中。
   - 文件:`floating_shell.tscn`、`floating_shell.gd`。
   - 依赖:bg 纹理导入需 **repeat=Enabled** 才能平铺(EI 导入设置,见 R4);占位阶段
     若未设,平铺会拉伸——Implementer 可临时在 `.import` 或代码兜底。
   - 验证:Play → 全宽底显示横向平铺背景,中央 800×250 区域居中;把窗口/屏幕想象更宽时
     主区仍居中不拉伸(可临时改 viewport 宽度模拟)。

4. **占位角色 + 待机微动。**
   - 动作:`MainArea` 下加 `Hero`(`Sprite2D`,贴 `hero_warrior_placeholder.png`,
     pivot 脚底居中——置于主区底部水平中点,纹理 128×160 脚底已贴底行);加子
     `AnimationPlayer`,一条 autoplay+loop 的 `idle`:position.y 轻微上下(±约 3–4px,
     周期 ~2s)、scale 微呼吸(±1–2%)、可选 modulate 微变。
   - 文件:`floating_shell.tscn`、`idle` 动画(存进 tscn 或 `.tres`)。
   - 验证:Play → 角色站主区底部居中、朝右,**持续轻柔上下浮动**,循环不停、不抢眼。

5. **收起/展开状态机 + handle + 平滑过渡(D3/D8)。**
   - 动作:`floating_shell.gd` 加状态 `enum {EXPANDED, COLLAPSED}`。加 `Handle`
     (`TextureButton`/`TextureRect`,贴 `icon_handle_placeholder.png`,64×64,默认隐藏)
     与 `CollapseBtn`(展开态可见的小收起按钮)。切换时用 `Tween` 对窗口 rect 缓动 ~0.25s:
     - 收起:窗口 → `Vector2i(64,64)`,位置到工作区右下角(`ur.end - Vector2i(64,64)`);
       隐藏 BgStrip/MainArea/CollapseBtn,显示 Handle。
     - 展开:还原全宽×250 贴底;反向切显示。
     `toggle_collapse`(F1)与点 Handle/CollapseBtn 都触发切换。切换时按 D6 调 `max_fps`。
   - 文件:`floating_shell.tscn`、`floating_shell.gd`。
   - 验证:Play → 触发收起:窗体平滑滑成右下角小 handle,**屏幕底部空间被释放**(不再挡东西);
     点 handle → 平滑还原全宽条;过渡顺滑不瞬切。

6. **置顶切换(D8)。**
   - 动作:`_input`/`_unhandled_input` 接 `toggle_always_on_top`(F2),翻转
     `DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, on)`,记当前态。
   - 文件:`floating_shell.gd`。
   - 验证:窗口聚焦时按 F2 → 置顶关:点其它窗口能盖住它;再按 → 置顶开:重回最前。
     (注:仅聚焦时生效,见 R2。)

7. **边缘容错(§3)。**
   - 动作:定位/取屏失败时兜底——`usable_rect` 异常则退回主屏整屏底部估算位;窄屏走 step 3
     缩放;**待机动画的启动与循环不依赖定位成功**(动画在节点就绪即跑,定位失败也照动)。
   - 文件:`floating_shell.gd`。
   - 验证:临时制造定位失败(如喂非法 screen index)→ 程序不崩、角色仍在动、窗口落在兜底位。

## 4. Out of scope / 明确不做
- 透明窗 / 点击穿透 / 拖动窗口(§6 砍)。
- 多显示器精调、记忆上次位置、设置面板(§6 砍)。
- 音频(§4 本期可空)。
- 收起态 handle 的"还在挂机"微提示动画 → 推到 02(§3 F4)。
- 全局(失焦也响应)快捷键(见 R2)。
- 存档 / autoload(本功能是纯容器,不产生需持久化的状态)。
- 正式美术替换、调色板 hex、背景无缝修复(ACCEPTANCE 软 flag,留正式美术阶段)。

## 5. Risks & Flags / Open questions
- **R1〔实现层,有退路〕** 逐帧 Tween OS 窗口几何(D3)在 Windows 上可能略抖。先按 D3 做;
  若实测明显卡顿,退路:窗口几何瞬切 + 仅内容滑动缓动来保留"滑"感。
- **R2〔产品取舍,已决+留后〕** Godot 仅在窗口聚焦时收键盘输入,**F1/F2 在别的程序聚焦时不响应**。
  本期主路径是点 handle/按钮(聚焦时必可用),快捷键作补充。真正的全局热键需 OS 级注册
  /插件(撞 hard-NO 不引插件)→ 推后。**建议:** 接受本期"焦点内热键",全局热键另立 backlog。
- **R3〔需目标机实测〕** D2 依赖 `screen_get_usable_rect` 在 Windows 真能避开任务栏。
  step 2 验证时必须肉眼确认不压任务栏;若该 API 在某些 DPI/多屏下不准,需回退到手测任务栏高。
- **R4〔依赖 EI〕** 背景平铺要求纹理导入 **repeat=Enabled**、且三图按平滑风导入预设
  (Lossless/Linear/Mipmaps off/Fix Alpha Border)。这些是 Engine Integrator 的导入设置;
  Implementer 接入时若 EI 未先行,平铺/滤镜可能不对——需协调顺序(建议 EI 先导入再 Implementer 接)。
- **R5〔细节,已给方案〕** 屏宽 <800 的兜底用等比缩放主区(D7/step3),非裁切;若未来要支持
  极窄屏的更优布局,另议。
- **R6〔已知坑,step1 处理〕** 空项目仍是 3D 默认(Forward+ / Jolt)。step1 切 Compatibility;
  3D 物理不启用即可,无需卸载。
- **置顶切换快捷键** 默认定为 **F1=收起切换 / F2=置顶切换**(FEATURE-DESIGN 留给实现层的细节);
  如与你习惯冲突,Implementer 可在 InputMap 改键,不影响结构。

---
artifact: CHANGES
feature: 01-floating-window-shell
role: Implementer
status: draft
updated: 2026-06-18
inputs: [PLAN.md, project-context.md, ACCEPTANCE.md, INTEGRATION-STEPS.md(Phase1), project.godot, REVIEW.md]
next: Producer(标记完成回 BACKLOG)
---

# CHANGES — 悬浮窗外壳 (Floating Window Shell)

## 1. 概述 / Summary
实现 PLAN 全部 7 步。主窗口即悬浮窗(D1):无边框、置顶、运行时贴主显示器工作区底部
(D2)。含横向平铺背景 + 800×250 居中主区(窄屏等比兜底)、占位战士待机微动、收起/展开
状态机(窗口 rect 缓动收成右下角 64×64 handle)、F1 收起切换 / F2 置顶切换。
**采用"代码 + 手写 .tscn"路线**:节点树、纹理引用、脚本挂载全部在 .tscn 内写定,
编辑器侧无需拖拽接线——给非程序用户的编辑器操作降到最低。

## 2. 改动文件 / Files changed
- **新增** `src/shell/floating_shell.gd` — 外壳控制器(全部逻辑)。
- **新增** `scenes/shell/floating_shell.tscn` — 主场景,节点树 + 3 张纹理已内部引用 + 已挂脚本。
- **改** `project.godot`:
  - `[application] run/main_scene="res://scenes/shell/floating_shell.tscn"`
  - `[display] window/size/borderless=true`
  - `[display] window/size/always_on_top=true`
  - `[display] window/size/transparent=true` + `window/per_pixel_transparency/allowed=true`(验收后加,见 §8)
  - stretch=disabled 为默认值,未显式写(D7)
  - (渲染 `gl_compatibility`、视口 1280×250 已由 EI Phase 1 落地,未动)

## 3. 对照 PLAN 步骤 / How it maps to the plan
- **step1** 项目设置:main_scene / borderless / always_on_top / stretch=disabled 已落
  `project.godot`。**InputMap 动作改为代码内原始键码**(见 §4 偏离 1)。
- **step2** 骨架 + 贴底定位:根 `Control` 挂脚本;`_ready()` → `_resolve_usable_rect()`
  用 `screen_get_usable_rect(当前屏)`,`_apply_expanded_geometry()` 设窗口 size=(工作区宽,250)、
  position=(工作区左, 工作区底-250)。
- **step3** 背景平铺 + 居中主区:`BgStrip`(TextureRect,`stretch_mode=1`/TILE、
  `texture_repeat=2`/ENABLED 节点级,见 §4 偏离 4 修正)。`MainArea` 由 `_layout_main_area()`
  代码居中;窗宽<800 时 `scale=win_w/800` 等比缩放并保持居中(R5)。
- **step4** 角色 + 待机微动:`MainArea/Hero`(Sprite2D,centered,position=(400,170) → 脚底贴
  250 底)。微动由 `_process` 正弦驱动 position.y(±`idle_bob_amplitude`)+ scale 呼吸
  (±`idle_scale_amplitude`),周期 `idle_bob_period`。**用代码而非 AnimationPlayer**(§4 偏离 2)。
- **step5** 收起/展开状态机:`enum State{EXPANDED,COLLAPSED}`;`_set_state()` 重算工作区 →
  对窗口 rect 用 `Tween.tween_method` + lerp 缓动 `transition_duration`(默认 0.25s,EASE_OUT/
  TRANS_CUBIC);收起目标=右下角 64×64;切换时切 `Engine.max_fps`(D6);`_refresh_visibility()`
  按态切显 BgStrip/MainArea/CollapseBtn vs Handle。Handle/CollapseBtn 的 `pressed` 在
  `_ready()` 内 `connect` 到 `_on_toggle_pressed`。
- **step6** 置顶切换:`_toggle_always_on_top()` 翻转
  `window_set_flag(WINDOW_FLAG_ALWAYS_ON_TOP, on)`,F2 触发。
- **step7** 边缘容错:`_resolve_usable_rect()` 在工作区尺寸非法时退回主屏整屏底部;待机微动
  在 `_process` 跑、不依赖定位成功(定位失败角色仍动);几何缓动 `transition_duration<=0`
  时退化为瞬切(R1 退路已内建)。

## 4. 偏离 PLAN / Deviations(均可逆、有理由)
1. **〔step1/D8〕F1/F2 用代码内原始键码,不建 InputMap 动作。** `_unhandled_input` 直接比对
   `event.keycode == key_toggle_collapse/always_on_top`(`@export` 默认 F1/F2,可改)。
   *理由:* 手写 InputMap 进 `project.godot` 序列化易错且非必要;本期热键仅焦点内生效(R2),
   原始键码足够,且免去用户在 Input Map 面板手动加动作。
2. **〔D4〕待机微动用 `_process` 正弦,不用 AnimationPlayer。** *理由:* 美术只交付单张静态
   PNG(微动属 game-feel);代码方案零编辑器工时、参数 `@export` 可调,仍满足"单张静态 +
   运行时动"约定。若后续要美术可视化调曲线,可换回 AnimationPlayer。
3. **〔接线〕3 张纹理在 .tscn 内用 `ext_resource` 直接引用,不暴露 `@export` 纹理字段。**
   *理由:* .tscn 由 Implementer 手写,纹理已就位,无需编辑器拖拽;节点引用走 `@onready $Path`。
   → **Wiring Contract 因此很轻**(见 §5)。
4. **〔修正 PLAN R4 措辞〕平铺靠节点 `texture_repeat=Enabled`(=2)+ `stretch_mode=Tile`(=1),
   非"导入 repeat"。** 已在 BgStrip 节点上设,作用域最小,不动项目全局默认(与 EI 旗标 F2 一致)。

## 5. Wiring Contract(给 Engine Integrator)
> 本功能"代码 + 手写 .tscn"自洽,**EI Phase 2 主要是核对而非拖拽接线**。

**主场景:** `res://scenes/shell/floating_shell.tscn`(已设为 `run/main_scene`)。

**节点树(已写定):**
```
FloatingShell (Control, full rect)         ← 挂 src/shell/floating_shell.gd
├── BgStrip   (TextureRect, full rect)       stretch_mode=1(TILE), texture_repeat=2(ENABLED), texture=bg
├── MainArea  (Control, 800×250)             position/scale 由代码 _layout_main_area() 设
│   └── Hero  (Sprite2D, centered)           position=(400,170), texture=hero
├── Handle    (TextureButton, 64×64)         visible=false(默认), texture_normal=icon
└── CollapseBtn (Button)                      text="收起", 右上角
```

**纹理引用(已在 .tscn 内,无需拖拽):**
- bg → `uid://cre8sgqp3sigx` (`res://assets/sprites/bg/bg_strip_placeholder.png`)
- hero → `uid://ban8d4hvlftb3` (`res://assets/sprites/placeholder/hero_warrior_placeholder.png`)
- icon → `uid://dgj2j4by5181m` (`res://assets/sprites/placeholder/icon_handle_placeholder.png`)

**信号(已在脚本 `_ready()` 内 `connect`,无需在编辑器连):**
- `Handle.pressed` → `_on_toggle_pressed`
- `CollapseBtn.pressed` → `_on_toggle_pressed`

**项目设置(已落 `project.godot`,EI 仅核对就位):**
- `application/run/main_scene` = 上述场景
- `display/window/size/borderless=true`、`always_on_top=true`、`stretch/mode="disabled"`
- **无 InputMap 动作**(热键走代码,见 §4 偏离 1)——EI 不需要在 Input Map 面板加任何动作。

**可调 `@export`(在 FloatingShell 根节点 Inspector,EI/用户可调,非必须):**
`content_fade_duration`(0.12)、`idle_bob_amplitude`(4)、`idle_bob_period`(2)、
`idle_scale_amplitude`(0.015)、`fps_expanded`(60)、`fps_collapsed`(15)、
`key_toggle_collapse`(F1)、`key_toggle_always_on_top`(F2)。

**EI Phase 2 需核对/确认的点:**
1. 场景能打开、脚本无解析错(我**无法本地跑** `godot --headless --check-only`,见 §6)。
2. Play 后窗口贴工作区底、不压任务栏(R3 目标机实测)。
3. BgStrip 真平铺不拉伸(确认 `texture_repeat`/`stretch_mode` 生效;若全局 `default_texture_repeat`
   影响,作用域以节点为准)。
4. 收起/展开窗口几何缓动是否在 Windows 抖动(R1;抖则把 `transition_duration` 调 0 走瞬切退路)。

## 6. 验证状态 / Verification
- ⚠ **`godot --headless --check-only` 未跑**:本环境 godot 不在 PATH(已确认 `NOT_FOUND`)。
  脚本与场景为手写,**解析/运行验证留给 EI Phase 2 在编辑器内 + 人工 Play**。
- 代码侧自检:节点路径与 `@onready` 一致(`$BgStrip`/`$MainArea`/`$MainArea/Hero`/`$Handle`/
  `$CollapseBtn`);枚举/常量/信号连接齐全;TextureRect tile=1 / repeat=2、Sprite2D 脚底贴底
  (160 高 centered 于 y=170 → 底 =250)经手算核对。
- 期望行为(Play):屏幕底部全宽 250 条 → 平铺背景 + 居中 800 主区 + 战士轻柔上下浮;点"收起"
  或 F1 → 平滑收成右下角 handle 释放屏幕;点 handle → 唤回;F2 切置顶(窗口聚焦时)。

## 7. Open issues / flags(滚动到 HANDOFF)
- R1 窗口几何缓动抖动风险(退路已内建:`transition_duration=0`)。
- R2 F1/F2 仅窗口聚焦时响应(全局热键需插件,本期不做)。
- R3 `screen_get_usable_rect` 避开任务栏需目标机实测。
- R4 已按节点级 `texture_repeat` 修正(见 §4.4)。
- 软美术 flag(背景接缝/信息量)留正式美术阶段(ACCEPTANCE F-BG1/F-BG2)。

## 8. 修订 / Revisions(2026-06-18,人工验收后)
人工 Play 验收通过(窗口贴底、平铺、角色微动、收起/展开、F2 置顶均 OK),修两处小问题:
1. **收起动画卡顿(bug)**:`_set_state` 在缓动**开始前**就把 `Engine.max_fps` 降到 `fps_collapsed`
   (15),0.25s 动画只剩 ~4 帧。改为:过渡期间保持 `fps_expanded`,降帧推迟到
   `_on_geom_tween_finished()`。
2. **收起 handle 有灰方块底**:灰块是 64×64 窗口自身不透明背景(非图标)。**经用户拍板,重新
   启用 §6 当初砍掉的窗口透明**:`project.godot` 加 `window/size/transparent=true` +
   `per_pixel_transparency/allowed=true`。展开态因 BgStrip 不透明满铺,外观不变;收起态只剩
   图标不透明像素 → 干净悬浮盾牌。
   - 配套:收起的可见性切换**延后到缓动结束**(`_on_geom_tween_finished` 内),避免透明窗下
     收起途中图标在透明区"乱飞";展开仍立即显示内容随窗口长出。
   > ⚠ 偏离原 §6"砍透明窗"——是用户在验收后的明确决定,非 Implementer 自行扩范围。
   > Windows per-pixel 透明在个别显卡/DPI 下可能有小瑕疵,需 EI/人工再确认一次收起态外观。
3. **收起/展开过渡改为"交叉淡变 + 几何瞬切"(取代逐帧缓动窗口几何)。** 第 1 版按 PLAN D3 逐帧
   `window_set_position/size` 缓动,即使 60fps 在 Windows 上仍明显"跳格"抖动(PLAN R1 预判)。
   新方案(用户提议方向):① 把根 `Control` 的 `modulate:a` 淡到 0(内容淡出)→ ② 此刻窗口全透明
   不可见,**直接跳变**窗口几何到目标(抖动不可见)→ ③ `_refresh_visibility` 切换显示节点 →
   ④ `modulate:a` 淡回 1。观感=横条淡出→角落盾牌淡入,无几何抖动。
   - **接口变更**:`@export transition_duration`(0.25,几何缓动时长)→ **`content_fade_duration`**
     (0.12,单段淡变时长)。Wiring Contract §5 的 @export 列表已同步。
   - 这是 PLAN R1 退路("瞬切几何 + 内容做缓动")的落地,纯 alpha 缓动天然平滑。

## 9. 修订 / Revisions(2026-06-18,REVIEW 后清 nit)
按 `REVIEW.md` 两项非阻塞 nit 做纯清理,**无行为变更**:
1. **删死分支 `_apply_expanded_geometry(instant)`**(REVIEW §3)。它是 §8.3 交叉淡变重构后的残留:
   只在 `_ready()` 以 `true` 调一次,且 `if instant:` 无 `else`(传 `false` 即空操作)。现把
   `_ready()` 改为复用过渡同一路径 `_snap_window(_expanded_rect())`(它已 set size/pos + 布局),
   函数整体删除。消除"似乎存在非瞬时展开路径"的误导,合 project-context §4 hard-NO(不留脚手架)。
2. **`_layout_main_area` 改为接 `win_w: float` 形参**(REVIEW §4)。原先它内部读
   `DisplayServer.window_get_size().x`,隐含依赖"`window_set_size()` 后 `window_get_size()` 立刻
   返回新值"。现由唯一调用方 `_snap_window(target)` 显式传 `float(target.size.x)`,去掉该隐式假设,
   更稳更易读。脚本内已无任何 `window_get_size()` 读取。
- **验证**:`godot.exe --headless --path . --check-only --script res://src/shell/floating_shell.gd`
  → 退出码 0、无解析/编译错误(本轮首次真正跑通 headless 校验,补上 §6 当初因 godot 不在 PATH 的缺口)。
- **Wiring Contract 影响**:无。节点树/纹理/信号/项目设置/`@export` 列表(§5)全部不变;两处均为
  私有方法内部重构,无对外接口改动。EI 无需重新核对。
- **⚠ 旁路发现(给 EI / INTEGRATION-STEPS)**:本机实际 Godot 可执行文件名是
  `G:\Godot\Godot_v4.6.3\godot.exe`,而 INTEGRATION-STEPS 命令里写的
  `Godot_v4.6.3-stable_win64.exe` 在本机不存在(`_console.exe` 是转发到该缺失名的 stub)。
  你交互执行时若用对了就忽略;否则 EI 文档里的路径建议更正为 `godot.exe`。

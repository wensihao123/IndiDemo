---
artifact: REVIEW
feature: 01-floating-window-shell
role: Reviewer
status: accepted
updated: 2026-06-18
inputs: [project-context.md, PLAN.md, CHANGES.md, src/shell/floating_shell.gd, scenes/shell/floating_shell.tscn, project.godot]
next: Producer(标记完成回 BACKLOG) / 或直接收尾
---

# REVIEW — 悬浮窗外壳 (Floating Window Shell)

> 审 `src/shell/floating_shell.gd` + `scenes/shell/floating_shell.tscn` 的代码质量。
> 功能已过人工 Play 验收 + EI Phase 2 接线验收;本审针对**代码本身**,不复测运行表现。

## 1. Verdict
**APPROVE WITH NITS** —— 正确、忠于 PLAN(偏离均已记录且经用户拍板)、无安全/过度设计问题。
两处可清理项不阻塞,留给后续顺手或下次碰这文件时处理即可。

## 2. Must-fix(blocking)
无。

## 3. Should-fix(non-blocking)
- **`src/shell/floating_shell.gd:105-109` `_apply_expanded_geometry(instant)` 的 `instant`
  形参是交叉淡变重构(CHANGES §8.3)后的残留死分支。** 现在只在 `_ready()` 一处以 `true`
  调用,过渡期的几何跳变已改走 `_snap_window()`(157-159);函数体里 `if instant:` 没有
  `else`,传 `false` 等于空操作,实际从无 `false` 调用方。
  *为什么要紧:* project-context §4 hard-NO 明确"不为没影的东西提前抽象 / 留脚手架"。这是
  上一版逐帧缓动留下的接口残骸,会让读者以为存在一条"非瞬时展开"路径(其实没有)。
  *建议方向:* 去掉形参与 `if`,直接 `func _apply_expanded_geometry()` 内两行 set;或干脆
  让 `_ready()` 调 `_snap_window(_expanded_rect())` 复用同一路径,删掉本函数。

## 4. Nits(optional)
- **`floating_shell.gd:157-160` `_snap_window()` 隐式依赖 `window_set_size()` 后
  `window_get_size()` 立刻返回新值**(`_layout_main_area()` 读的是 `window_get_size()`)。
  Windows 下 DisplayServer 该调用同步、实测也对,但这条隐含假设没写出来。可把 `target.size.x`
  直接传给 `_layout_main_area(win_w)`,去掉对"set 后立刻 get"的依赖,更稳也更易读。
- **`floating_shell.gd:64` `_idle_time` 收起后不归零、再展开从旧相位续。** 无视觉问题(正弦
  连续),仅提一句;若想每次展开都从静止位起,可在转 EXPANDED 时 `_idle_time = 0.0`。

## 5. What I checked but found fine(覆盖说明)
- **几何数学**:`_expanded_rect()`(贴 `usable_rect` 底、全宽×250)、`_collapsed_rect()`
  (右下角 64×64)、`_resolve_usable_rect()` 取屏失败退回 screen 0 整屏——均正确,兜底符合
  PLAN step7。
- **状态机再入**:快速反复 toggle 时 `_geom_tween.kill()` 先杀旧 tween,新序列末尾必把
  `modulate:a` 拉回 1,不会卡在半透明;`_set_state` 对同态 early-return。无死锁/残留态。
- **可见性/透明交互**:收起的显隐切换排在 `_snap_window` 之后、且整段在 `modulate:a=0`
  期间发生,配 per-pixel 透明不会出现"收起途中图标在透明区乱飞"。淡变作用于根 Control 的
  modulate,子节点(含 CollapseBtn/Handle)随之,符合预期。
- **微动开销**:`_process` 在非 EXPANDED 态 early-return,收起态 `max_fps=15`——契合支柱 1
  "不打扰/省资源",不空转。
- **PLAN 忠实度**:3 处偏离(InputMap→原始键码 / AnimationPlayer→`_process` 正弦 / 几何缓动→
  交叉淡变)均在 CHANGES §4/§8 记录、可逆、且经用户验收拍板,非偷偷漂移。
- **约定(project-context §3)**:文件 snake_case、节点 PascalCase、`_process` 早返回、注释只
  解释"为什么"(如几何瞬切规避 Windows 抖动)——都符合。
- **硬编码检查**:`MAIN_WIDTH=800 / EXPANDED_HEIGHT=250 / COLLAPSED_SIZE=64×64` 是 spec 定死
  的布局常量(§3 主区 800×250),非平衡数值;可调项(淡变时长/微动/帧率/热键)已走 `@export`。
  未触 hard-NO(无新插件、无计划外重构/加功能、无平衡参数入逻辑)。
- **安全**:纯本地 UI 外壳,无外部输入/授权/密钥/注入面,N/A。
- **.tscn**:节点树/类型/层级与 Wiring Contract §5 及 `@onready` 路径一致;BgStrip
  `texture_repeat=2`+`stretch_mode=1`、Hero `position=(400,170)` 脚底贴 250 底,核对无误。

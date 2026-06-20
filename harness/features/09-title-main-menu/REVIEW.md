---
artifact: REVIEW
feature: 09-title-main-menu
role: Reviewer
status: done
updated: 2026-06-20
inputs: [harness/features/09-title-main-menu/PLAN.md, harness/features/09-title-main-menu/CHANGES.md, src/shell/game_flow.gd, src/shell/floating_shell.gd, src/core/game_controller.gd, src/combat/combat_view.gd, src/combat/town_view.gd, scenes/shell/floating_shell.tscn]
next: 各 role 回写事实源(步 6)/ Art Spec(占位视觉)
---

# REVIEW · 09-title-main-menu(前门 + 系统枢纽)

> 对照 PLAN §2 决策 D1-D7 + CHANGES Wiring W1-W7,读**真实代码**(非仅 CHANGES)。
> 已知:`--check-only` 0 error、gdUnit4 156/156、人手动 Play(D1-D9)验收通过。本评审聚焦代码层面。

## 1. 结论 / Verdict
**APPROVE WITH NITS** — 实现忠于 PLAN,层次与不变量守得干净,无 must-fix、无 should-fix 级缺陷。
仅有几处不影响正确性的 nit(占位/风格),可并入后续 Art Spec·juice 一轮,不阻塞。

支柱 1 红线(菜单覆盖层**不暂停** sim)在代码层确认守住:`open_menu()` / `_resume_to_source()` 全程
不触 `Game.arena.running`(W5),与人手动 D3 验收一致。

## 2. 必修 / Must-fix
无。

## 3. 应修 / Should-fix
无。

以下为我认真追过、确认**不是**缺陷的几条(留痕,免下游重复怀疑):
- `_resume_to_source()` 不调 `resume_run` 看似漏恢复 —— 实为正确:菜单从不暂停,来源态 running 原样保留
  (EXPLORE 仍在打、TOWN 仍由 TownView 暂停)。调 resume 反会对"未暂停的 EXPLORE"误 resume。守 W5/D6。
- `open_menu()` 不隐 CombatView/TownView 看似会漏底层 —— 实为双保险:MENU 几何下 `floating_shell._refresh_visibility`
  已隐 `main_area`,菜单屏 bg 又是 0.98 不透明 + `MOUSE_FILTER_STOP`。底层视图态被原样冻结,resume 时恢复。这正是
  "GameFlow 不跟踪城镇态"能成立的原因(D6),设计自洽。
- `gf.open_menu(...)`(combat/town_view.gd:103/211)对 `Node` 类型做动态方法调用 —— 与本仓库 `_gc: Node` 同款,
  `--check-only` 放行,GDScript 合法。一致,非问题。

## 4. Nits(不阻塞,可并入 Art Spec·juice 轮)
- **N1 `combat_view.gd:570` `_menu_btn` 占位坐标 (596,12)** 与 `_enemy_name`(596,64)同列、与 `_push_btn`(660,12)/
  `_panel_btn`(360,12)同行,挤占顶栏。已知占位,CHANGES W7 / INTEGRATION-STEPS Flags 已记,交 Art Spec。非代码缺陷。
- **N2 `town_view.reset_to_combat()`(64-68)与 `_leave_town`(52-60)体除 `resume_run` 外重复**。当前是有意为之
  (注释已说明边界),三行重复优于过早抽象,符合本仓库基调;若将来第三处复位出现再抽 `_show_combat_views()`。保留。
- **N3 启动首帧贴底条闪**(`call_deferred("_enter_title")` 的已知代价,CHANGES §5)。父子 `_ready` 顺序所迫,
  判定可接受,留 Art Spec 抛光(淡入遮一帧)。非缺陷。

## 5. 我查过但认为没问题 / Checked & fine
- **忠于 PLAN(D1-D7)**:D1 GameFlow 落表现层(`extends Control`,只向下调 Game、横向调 shell,逻辑层零反依赖,
  守 ARCHITECTURE §3.3)✅;D2 四屏纯 show/hide(`_show_only`/`_hide_all_screens`),无 ScreenManager/基类 ✅;
  D3 只调 shell 两个公开几何 API,不私改 `_set_state`/`_snap_window` ✅;D4 MENU 复用几何 FSM(floating_shell
  `match` 分支),无逐帧 window tween ✅;D5 `GameController.new_game(stages)` 存在且 reset→roster→begin_run→
  存档 ✅;D6 `[☰]` 显式带来源态 `Return.EXPLORE/TOWN` ✅;D7 `get_first_node_in_group("game_flow")` 不写死路径 ✅。
- **步 3+4 同批(W2,空窗红线)**:`combat_view._ready` 已删自动 `begin_run` + `@export stages`;唯一开打入口
  收拢到 GameFlow `on_continue`/`_do_new_game`。.tscn 里 CombatView 已无 `stages`、GameFlow 节点持 stage_01/02。
  摘旧触发与建新触发在同一批,无中间空窗态。✅
- **Esc 约定(D8)**:子屏可见 → 退一级回主菜单(对 TITLE/MENU_OVERLAY 都成立);MENU_OVERLAY 顶层 = 继续回来源;
  TITLE 顶层无出口。`_unhandled_input` 逻辑与三态期望一一对上,且 `set_input_as_handled()` 防穿透。✅
- **几何收起边界(D9)**:`floating_shell._toggle_collapse` 开头 `if _state==MENU: return`(MENU 态 F1 无反应);
  `_process` idle-bob `if _state != EXPANDED: return`。✅
- **破坏性二次确认**:有档新游戏 → `_overwrite_screen`;退出 → `_quit_screen`;取消/Esc 均回主菜单。✅
- **group 注册时序**:GameFlow/TownView 在各自 `_ready` `add_to_group`;`[☰]` 仅运行时按下查找,远晚于所有 `_ready`。无空查风险。✅
- **续战游标**:`on_continue`(TITLE)走 `begin_run(stages)` 默认参 <0 → 取 `_resume_stage/_resume_scene`(存档已填),续到存档进度;无档时「继续」disabled 不触发该路径。✅
- **安全**:本功能无外部输入/网络/文件路径拼接;`quit_game` 退出前 `_autosave`。无注入面。✅

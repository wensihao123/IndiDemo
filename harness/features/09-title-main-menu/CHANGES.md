---
artifact: CHANGES
feature: 09-title-main-menu
role: Implementer
status: draft
updated: 2026-06-20
inputs: [harness/features/09-title-main-menu/PLAN.md, harness/arch/REFACTOR-05-game-flow-coordinator.md, harness/state/STATE-CHANGE-01-title-main-menu.md, harness/ux/UX-CHANGE-01-title-main-menu.md, src/core/game_controller.gd, src/shell/floating_shell.gd, src/combat/combat_view.gd, src/combat/town_view.gd, scenes/shell/floating_shell.tscn]
next: Reviewer
---

# CHANGES · 09-title-main-menu(前门 + 系统枢纽)

## 1. 做了什么 / Summary
给"启动即开打"的悬浮窗补上**表现层 `GameFlow` 协调节点**:启动落居中主菜单窗(继续/新游戏/设置/退出),
选完收缩贴底进游戏;游戏中右上 `[☰]` 随时回主菜单覆盖层。流程决策从 CombatView/TownView 收拢成一台显式
流程机。照 PLAN §3 六步落地(步 6 = 各 role 回写事实源,非本 role)。

## 2. 改了哪些文件 / Files touched
- **`src/core/game_controller.gd`**(步 1,纯加法)— 加 `var has_save := false`;`_boot` 在 load 存档后落
  `has_save = not save.is_empty()`;加 `new_game(stages)`(reset→起始 roster→`begin_run(stages,0,0)`→
  `has_save=true`→`_autosave()`,覆盖单档)、`quit_game()`(`_autosave()`→`get_tree().quit()`)。
  `begin_run/pause_run/resume_run` 签名与逻辑未动。
- **`src/shell/floating_shell.gd`**(步 2,纯加法,COLLAPSED 路径不动)— `enum State` 加 `MENU`;加
  `const MENU_SIZE := Vector2i(560,400)`(占位,交 Art Spec)+ `_menu_rect()`(工作区居中);`_set_state`
  target 选择改 `match`,支持 `MENU`(复用淡出→跳变→淡回,MENU 不降帧);`_refresh_visibility` MENU 分支
  全隐 strip/main_area/collapse_btn/handle;公开 API `enter_menu_geometry()`/`enter_game_geometry()`;
  `_toggle_collapse` 开头 `if _state==MENU: return`(MENU 无收起出口)。
- **`src/shell/game_flow.gd`**(步 3+4+5,**新建**,`extends Control` / `class_name GameFlow`)— 流程机:
  `enum Flow{BOOT,TITLE,EXPLORE,TOWN,MENU_OVERLAY}` + `enum Return{NONE,EXPLORE,TOWN}` + `@export stages`;
  `_ready` 入组 `game_flow`、取 `/root/Game`、`_shell=get_parent()`、建四菜单屏、`call_deferred("_enter_title")`;
  转移方法 `on_continue/on_new_game/on_open_settings/on_settings_back/on_quit/on_quit_confirm/on_quit_cancel/
  on_overwrite_confirm/on_overwrite_cancel/open_menu/_resume_to_source`;`_unhandled_input` 管 Esc;
  四菜单屏代码建(占位视觉,交 Art Spec)。
- **`src/combat/combat_view.gd`**(步 3+5)— 删 `@export var stages` + `_ready` 内自动 `begin_run`;`_build_ui`
  加 `[☰]` 按钮 → `_on_menu_pressed()` 经 group 调 `GameFlow.open_menu(Return.EXPLORE)`。
- **`src/combat/town_view.gd`**(步 5)— `_ready` 入组 `town_view`;`_build_ui` 加 `[☰]` →
  `_on_menu_pressed()` 调 `open_menu(Return.TOWN)`;加公开 `reset_to_combat()`(新游戏后视图复位,不碰 running)。
- **`scenes/shell/floating_shell.tscn`**(步 3+4)— CombatView 删 `stages`;在 `FloatingShell` 下加
  `GameFlow` 节点(full-rect Control),挂 `game_flow.gd` + `stages`(stage_01/stage_02 ext_resource 搬来)。
- **`test/core/game_controller_test.gd`**(步 1 验证)— 加 3 例:`has_save` 关存档为假、`new_game` 重置+开局+
  落盘、重 boot 见档。

## 3. 验证 / Verification
- `godot --headless --check-only` — **0 error 0 warning**(新 `class_name GameFlow` 首验需先 `--editor --quit`
  重建 global class cache,否则 combat_view/town_view 报 "Identifier GameFlow not declared";已重建,见 §5 坑)。
- gdUnit4 全量:**156/156 PASS,0 orphan**(含 game_controller 13 例)。
- **手动 Play(未做,headless 不能验 GUI)→ 交 Engine Integrator / 人**:见 §6 待验清单。

## 4. 与 PLAN 的偏差 / Deviations
- **`TownView.reset_to_combat()` + group `town_view`**(PLAN 步 5 已点名为"deviation 容错"):新游戏可能从
  TOWN 来的覆盖层发起,若不复位城镇视图会留下陈旧 town_root。GameFlow `_enter_game` 经 group 调它把视图收回
  战斗态(纯视图复位,不调 resume_run——new_game 已 `begin_run` 重启 sim)。守 D6:GameFlow 不跟踪城镇态。
- **`MENU_SIZE` 合并为单个 `Vector2i` 常量**(PLAN 步 2 写的是 `MENU_WIDTH/MENU_HEIGHT` 两常量)— 与既有
  `COLLAPSED_SIZE := Vector2i(...)` 风格一致,语义等价。占位值 560×400,最终交 Art Spec。
- 其余完全照 PLAN;无结构/转移层偏差。

## 5. 踩的坑 / Notes for next role
- **新 `class_name` 不在 global class cache** → 引用它的脚本 `--check-only` 直接 parse error。修:跑一次
  `godot --headless --editor --quit --path .` 重建 `.godot/global_script_class_cache.cfg`(本仓库流程:新增
  带 class_name 的脚本后必做)。`.uid` 也由此生成,已回填进 .tscn ext_resource。
- **`_ready` 父子顺序**:GameFlow 是 FloatingShell 子节点,子 `_ready` 先于父 → 故 `_enter_title` 用
  `call_deferred`,等 FloatingShell `_ready`(snap 到 expanded)跑完再切 MENU 几何。代价 = 启动有一帧贴底闪
  再淡入居中菜单,**判定可接受**,记给 Art Spec 抛光。

## 6. 待验清单(手动 Play,交 Engine Integrator / 人)
- 有档:启动→主菜单(继续可点)→继续→收缩贴底进游戏,续战游标对。
- 无档:继续 disabled、新游戏→直接进 0-0 新局。
- 新游戏(有档)→覆盖确认→确定→新局;取消/Esc→回主菜单。
- 游戏中 `[☰]`→放大回主菜单、**sim 不暂停**(战斗日志持续);继续/Esc→回原态(Explore 续战 / Town 仍暂停)。
- 退出确认→确定→autosave 后退进程;取消/Esc→回主菜单。
- Esc:设置/两确认层退一级回主菜单;MENU_OVERLAY 顶层 Esc=继续;TITLE 顶层 Esc 无效。
- 几何无抖动(MENU↔strip 复用全透明瞬间跳变);F1 在 MENU 态无反应。

---

## Wiring Contract（接线契约 · 下游/Reviewer/EI 必读）

> 本功能新增/改动的接缝,下游接线与回归须照此对齐。

### W1 · 新节点 GameFlow 入场景(关键)
- `scenes/shell/floating_shell.tscn` 中 `FloatingShell` 直接子节点新增 **`GameFlow`**(full-rect Control,
  挂 `src/shell/game_flow.gd`),持 `@export stages = [stage_01, stage_02]`。**关卡表事实源从 CombatView 搬到此**。
- GameFlow `_ready` 入组 **`game_flow`**;`_shell = get_parent()`——故 GameFlow **必须是 FloatingShell 直接子**,
  移动层级会断 `_shell` 取用。

### W2 · 谁启动战斗(触发点搬家)
- **旧**:CombatView `_ready` 自动 `_gc.begin_run(stages)`(已删)。
- **新**:仅 GameFlow 触发 —— `on_continue()`(TITLE)调 `Game.begin_run(stages)`;`_do_new_game()` 调
  `Game.new_game(stages)`。**摘自动开打与引入 GameFlow 是同一不可分提交**(PLAN ⚠ 步 3+4),单独缺一即空窗。

### W3 · 视图 → GameFlow(group 查找,D7)
- CombatView/TownView 经 `get_tree().get_first_node_in_group("game_flow")` 取 GameFlow,调
  `open_menu(GameFlow.Return.EXPLORE | TOWN)`。**不写死 NodePath**。新增任何"回菜单"入口照此。

### W4 · GameFlow → floating_shell(几何 API,层内横向,D3)
- GameFlow 只调 shell 的两个公开方法:`enter_menu_geometry()` / `enter_game_geometry()`。
  **不得**私改 shell 的 `_set_state` / `_snap_window`(私有几何 FSM)。

### W5 · GameFlow → GameController(机制方法,向下依赖)
- 调用面:`Game.has_save`(读)、`Game.begin_run(stages)`、`Game.new_game(stages)`、`Game.quit_game()`。
- **不变量**:`open_menu()` / `_resume_to_source()` **绝不动** `Game.arena.running`(守支柱 1:菜单不暂停 sim)。
  仅 TownView 的 `_enter_town/_leave_town` 经 `pause_run/resume_run` 改 running(EXPLORE↔TOWN 维持现状,未进 GameFlow)。

### W6 · GameFlow → TownView(新游戏视图复位)
- `_enter_game()` 经 group `town_view` 调 `reset_to_combat()`(纯视图复位:隐 town_root、显 CombatView,
  **不调 resume_run**)。新增其它进游戏入口若可能从 TOWN 发起,须同样过此复位。

### W7 · 留给 Art Spec 的占位(并入全局 UI·juice 一轮)
- `MENU_SIZE` 560×400、四菜单屏视觉/排布、`[☰]` 图标与位置(占位文字 "☰",CombatView 在 (596,12)、
  TownView 在 town_root (650,10))、strip↔MENU 过渡手感、启动首帧贴底闪。**均占位,功能已跑通**。

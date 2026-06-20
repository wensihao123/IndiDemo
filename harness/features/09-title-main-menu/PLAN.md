---
artifact: PLAN
feature: 09-title-main-menu
role: Planner
status: draft
updated: 2026-06-20
inputs: [harness/arch/REFACTOR-05-game-flow-coordinator.md, harness/state/STATE-CHANGE-01-title-main-menu.md, harness/ux/UX-CHANGE-01-title-main-menu.md, ARCHITECTURE.md, STATE-MACHINES.md, project-context.md, src/core/game_controller.gd, src/shell/floating_shell.gd, src/combat/combat_view.gd, src/combat/town_view.gd, src/core/meta/player_state.gd, scenes/shell/floating_shell.tscn]
next: Implementer
---

# PLAN · 09-title-main-menu(前门 + 系统枢纽)

## 1. 目标 / Goal(一句话)
给"启动即开打"的悬浮窗补上**表现层 `GameFlow` 协调节点**:启动落居中主菜单窗(继续/新游戏/设置/退出),
选完收缩贴底进游戏;游戏中右上 `[☰]` 随时回主菜单——把散在 CombatView/TownView 的流程决策收拢成一台显式流程机。

## 2. 方案与关键决策 / Approach & key decisions

> 结构与转移由上游三份事实源钉死,本 PLAN 只做**文件级落地排序**。每条决策给 what + why + 被否选项。

- **D1 · 流程机归宿 = 新建表现层 `GameFlow` 节点(非进 core)**。what:`src/shell/game_flow.gd` 挂进
  `floating_shell.tscn`,持 `enum Flow`+`menu_return_to`,宿主四菜单屏;向下调 `Game` 机制方法、横向调
  `floating_shell` 几何 API。why:流程要路由"屏+几何"(表现层关切),放 core autoload 会逆依赖破 ARCHITECTURE
  §3.3(REFACTOR-05 §2)。**被否**:enum 进 `game_controller`(SMM 初始推荐)——逆依赖;详见 REFACTOR-05 §6。
- **D2 · 三屏沿用 show/hide,不上 ScreenManager/StateMachine 基类**。what:主菜单/设置/覆盖确认/退出确认 = GameFlow
  下四个兄弟 Control,`.visible` 切。why:4 个互斥简单屏够不上屏管理器,守 project-context hard-NO"不为还没影
  的后期系统提前抽象"。**被否**:引入 ScreenManager + 导航栈(过度工程,留屏长大后独立重构)。
- **D3 · flow→几何 = GameFlow 横向调 `floating_shell` 新公开 API**(presentation→presentation,层内合法)。
  why:几何归 floating_shell,GameFlow 不该私改其私有 `_set_state`。**被否**:shell 反向监听 flow signal——
  把流程关切塞进纯几何 FSM,污染它(REFACTOR-05 §6)。
- **D4 · `MENU` 几何复用既有"全透明瞬间跳变几何"退路,不逐帧缓动窗口几何**。why:Windows 改窗几何抖动
  (PLAN R1 已知坑);沿用 `_set_state` 那套 Tween(淡到全透明→跳变→淡回)。**被否**:对 window_position/size
  逐帧 tween——必抖。
- **D5 · `new_game()` 接缝住 GameController、签名带 `stages`**。what:`new_game(stages)` = `reset()` + 恢复 starting
  roster + `begin_run(stages,0,0)` + `has_save=true` + `_autosave()`(**覆盖**单档,无需 SaveSystem.delete)。why:
  begin_run 已需 stages 入参,new_game 与之对称;清档=落盘覆盖。**被否**:SaveSystem 加 `delete`——多余,落盘即清旧档。
- **D6 · `[☰]` 由发起视图传来源态**:CombatView 的 `[☰]`→`open_menu(EXPLORE)`、TownView 的 `[☰]`→`open_menu(TOWN)`。
  why:REFACTOR-05 §5 取舍让 EXPLORE↔TOWN 维持 TownView 现状、GameFlow **不跟踪**城镇态,故来源由发起方显式带入,
  `继续`时仅恢复几何、不动 TownView 已有可见性/running。**被否**:GameFlow 反查 town_root.visible 猜来源——耦合 TownView 内部。
- **D7 · 视图→GameFlow 用 group 查找(`game_flow`),不写死节点路径**。why:CombatView/TownView 在 `MainArea` 下、
  GameFlow 在 `FloatingShell` 下,跨层硬路径(`get_parent().get_parent()...`)脆。GameFlow `_ready` 入组,视图
  `get_tree().get_first_node_in_group("game_flow")` 取之。**被否**:硬编码 NodePath——重构即断。

## 3. 有序步骤 / Ordered steps

> ⚠ **步 3 与步 4 必须同批落地**(摘掉自动开打后若 GameFlow 入口未就位 = 空窗,REFACTOR-05 §4/§6)。
> 步 1、2 是纯加法,落地后旧流程仍能跑、可独立验。

### 步 1 · GameController 加机制接缝(纯加法)
- **改 `src/core/game_controller.gd`**:
  - 加字段 `var has_save := false`。
  - `_boot`:在 `save = save_system.load_file(...)` 之后(约 line 54-55 区域)落 `has_save = not save.is_empty()`。
  - 加 `func new_game(stages: Array[StageConfig]) -> void`:`player_state.reset()` → `player_state.roster =
    registry.get_starting_roster()` → `begin_run(stages, 0, 0)` → `has_save = true` → `_autosave()`。
  - 加 `func quit_game() -> void`:`_autosave()` → `get_tree().quit()`(供退出确认用,避免依赖 WM_CLOSE 通知)。
  - `begin_run/pause_run/resume_run` **签名与逻辑不动**。
- **验证(gdUnit4 纯逻辑,走 `_boot(load_save=false)` 注入)**:
  - boot 关存档 → `has_save == false`;喂一份已存档文件 boot → `has_save == true`。
  - `new_game(stages)` 后:`player_state.roster` 非空、`progression.cur_stage==0 && cur_scene==0`、存档文件存在。
  - 旧整体流程仍能启动开打(此步未动触发点,CombatView 仍自动 begin_run)。

### 步 2 · floating_shell 开几何接缝 + `MENU` 态(纯加法,COLLAPSED 路径不动)
- **改 `src/shell/floating_shell.gd`**:
  - `enum State { EXPANDED, COLLAPSED }` → 加 `MENU`。
  - 加常量 `MENU_WIDTH/MENU_HEIGHT`(占位 ~560×400,**最终值交 Art Spec**)+ `func _menu_rect() -> Rect2i`(在
    `_usable_rect` 内居中)。
  - `_set_state`:target 选择支持 `MENU`(→`_menu_rect()`);沿用既有淡出→跳变→淡回序列(**不新增逐帧几何缓动**)。
    MENU 不降帧(保持 `fps_expanded`)。
  - `_refresh_visibility`:加 `MENU` 分支——`bg_strip/main_area/collapse_btn/handle` 全隐(菜单屏由 GameFlow 自管)。
  - 公开 API:`func enter_menu_geometry()`(→`_set_state(MENU)`)、`func enter_game_geometry()`(→`_set_state(EXPANDED)`)。
  - F1 收起守卫:`_toggle_collapse` 开头 `if _state == State.MENU: return`(MENU 态无收起出口;`_process` 待机微动
    已对 `_state != EXPANDED` 早退,MENU 自然不 bob)。
- **验证(手动 Play)**:临时在 `_ready` 末调 `enter_menu_geometry()` → 肉眼确认窗口居中 ~560×400;按 F1 在 MENU 态
  无反应;调 `enter_game_geometry()` → 跳回贴底 800×250 无抖动。验完移除临时调用。

### 步 3 · 摘 CombatView 自动开打 + stages 迁出(⚠ 与步 4 同批)
- **改 `src/combat/combat_view.gd`**:删 `_ready` 内 `if not stages.is_empty(): _gc.begin_run(stages)`(line 98-99);
  删 `@export var stages: Array[StageConfig]`(line 9)。
- **改 `scenes/shell/floating_shell.tscn`**:CombatView 节点删 `stages = ...`(line 50);stage_01/stage_02/stage_config
  的 `ext_resource` 改挂到步 4 的 GameFlow 节点(数组随之搬家)。
- 单独此步**不可运行**(启动不再开打 = 空窗),必须随步 4 一起落地、一起验。

### 步 4 · 引入 `GameFlow` 协调节点(⚠ 与步 3 同批)
- **新建 `src/shell/game_flow.gd`**(`extends Control`,`class_name GameFlow`):
  - `enum Flow { BOOT, TITLE, EXPLORE, TOWN, MENU_OVERLAY }`、`var _flow := Flow.BOOT`;
    `enum Return { NONE, EXPLORE, TOWN }`、`var _menu_return_to := Return.NONE`。
  - `@export var stages: Array[StageConfig]`(承步 3 搬来的关卡表)。
  - `_ready`:入组 `add_to_group("game_flow")`;取 `Game = get_node("/root/Game")`、`_shell = 最近 FloatingShell`;
    `_build_screens()` 建四菜单屏(主菜单/设置/覆盖确认/退出确认,默认仅主菜单可见);落 `TITLE` →
    `_shell.enter_menu_geometry()` → 按 `Game.has_save` 切主菜单默认态(有档:继续=主操作;无档:继续 disabled/隐藏、新游戏=主)。
- **改 `scenes/shell/floating_shell.tscn`**:在 `FloatingShell` 下加 `GameFlow` 节点(full-rect Control),挂上
  `game_flow.gd` 与 `stages`(stage_01/stage_02);四菜单屏可代码建(减 .tscn 改动,同 CombatView `_build_ui` 风格)。
- **验证(手动 Play)**:启动落居中主菜单窗,四按钮可见;无任何自动开打;`has_save` 决定"继续"可点性。
  *(本批 = 步 3+步 4 合并验:启动→主菜单,不空窗。)*

### 步 5 · 接线转移(continue/new_game/设置/两确认/`[☰]`/Esc)
- **`game_flow.gd` 转移方法**(照 STATE-CHANGE-01 §3.1 转移表):
  - `on_continue()`:`Game.begin_run(stages)`(续战游标默认)→ `_shell.enter_game_geometry()` → 显 main_area/CombatView →
    `_flow=EXPLORE`、`_menu_return_to=NONE`。
  - `on_new_game()`:`Game.has_save` 真 → 弹覆盖确认子屏;假 → `Game.new_game(stages)` → 进游戏(同上几何收缩)。
  - 覆盖确认 `confirm` → `Game.new_game(stages)` → 进游戏;`cancel/Esc` → 回主菜单。
  - `on_open_settings()` → 显设置屏;设置 `back/Esc` → 回主菜单。
  - `on_quit()` → 弹退出确认;`confirm` → `Game.quit_game()`;`cancel/Esc` → 回主菜单。
  - `open_menu(src: Return)`(供 `[☰]`)→ `_menu_return_to = src`、`_flow=MENU_OVERLAY`、`_shell.enter_menu_geometry()`、
    **不动 `Game.arena.running`**(守支柱 1);主菜单按 `has_save` 切默认态。
  - MENU_OVERLAY `on_continue()` → `_shell.enter_game_geometry()` → 回 `_menu_return_to` 来源态(EXPLORE/TOWN);
    `running` 维持来源值(不调 begin_run/resume——TownView 状态原样保留);`_menu_return_to=NONE`。
- **Esc 约定**(GameFlow `_unhandled_input` 或屏内):子层(设置/两确认)`Esc`=退一级回主菜单;顶层 `MENU_OVERLAY`
  的 `Esc`=`on_continue`(回来源,UX-CHANGE-01 §0);顶层 `TITLE` 为根屏**无 Esc 出口**。
- **加 `[☰]` 入口**:
  - **改 `src/combat/combat_view.gd`**:`_build_ui` 加右上 `[☰]` 按钮(与 收起/推进 共处,排布占位交 Art Spec),
    `pressed` → `get_tree().get_first_node_in_group("game_flow").open_menu(GameFlow.Return.EXPLORE)`。
  - **改 `src/combat/town_view.gd`**:`_build_ui` 加 `[☰]`,`pressed` → `open_menu(GameFlow.Return.TOWN)`。
  - **进出城维持 TownView 现状**(`_enter_town/_leave_town` 不改,EXPLORE↔TOWN 不进 GameFlow)。
- **验证(手动 Play 全链路)**:
  - 有档:启动→主菜单→继续→收缩贴底进游戏(续战游标对)；无档:继续不可点、新游戏→直接进 0-0 新局。
  - 新游戏(有档)→覆盖确认→确定→新局;取消→回主菜单。
  - 游戏中 `[☰]`→放大回主菜单、**sim 不暂停**(战斗日志持续)；继续→回原态(Explore 战斗续/Town 仍暂停)。
  - 退出确认→确定→autosave 后退出进程。
  - Esc:设置/确认层退一级;MENU_OVERLAY 顶层 Esc=继续;TITLE 顶层 Esc 无效。
  - 进出城仍正常(pause/resume 不回血、不抖)。

### 步 6 · 回写事实源 🔜→现状
- 落地后:State Machine Master 把 `STATE-MACHINES.md` M2/M3 的 🔜 转现状;UX Design 把 `UX-MAP.md` §2/§4 转现状;
  ARCHITECTURE.md GameFlow 行 🔜 转现状(由对应 role 各自回写,非 Implementer)。

## 4. 不做 / Out of scope
- **MENU 窗尺寸 / 三屏视觉 / `[☰]` 图标 / strip↔MENU 过渡手感** = Art Spec(并入全局 UI·juice 一轮);本 PLAN 用占位尺寸+代码建屏跑通。
- **设置屏实质内容**(音量/键位重映射/关于)= 仅占位最简(为债 #6 留位),不做实际重映射逻辑。
- **EXPLORE↔TOWN 收编进 GameFlow**:维持 TownView 现有 pause/resume + 兄弟 `.visible`(REFACTOR-05 §5 取舍;屏可见性双发起点记入 ARCHITECTURE §6 债)。
- **ScreenManager / StateMachine 基类 / 统一 FSM 范式**(STATE-MACHINES §6.1)= 留屏数量长大后独立重构。
- **存档格式改动 / SaveSystem.delete / M1·M4 转移表改动**:零改动,仅 begin_run/running 触发点搬家。

## 5. 风险与 Flag / Risks & Flags
- **⚠ 步 3+4 同批**:摘自动开打与 GameFlow 入口必须一起落,否则启动空窗。Implementer 须把两步当一个不可分提交。
- **几何抖动**(Windows 改窗几何已知坑):MENU↔strip 复用"全透明瞬间跳变"退路,**禁逐帧缓动**(D4)。
- **菜单不暂停 sim**:久留回来已推进/团灭数轮——判定可接受(支柱 1 后台推进,UX-CHANGE-01 决策)。
- **`[☰]` 挤占战斗 HUD 右上**(已有 收起/推进/狂暴横幅):排布交 Art Spec,本 PLAN 仅占位一个角标入口。
- **autoload 顺序依赖**:GameFlow `_ready` 读 `Game.has_save`,依赖 Game(autoload)先于场景 `_ready` boot 完成——
  autoload 先于主场景实例化,成立;若 `auto_boot=false` 的测试场景则 GameFlow 须容错 `has_save` 默认 false。
- **Flag → Art Spec**:`/role-art-spec` 收 MENU 尺寸/三屏/`[☰]` 图标/过渡视觉(并入 UI·juice 一轮)。
- **Flag → 回写**:落地后 SMM / UX / Arch 各自把 🔜 转现状(步 6)。

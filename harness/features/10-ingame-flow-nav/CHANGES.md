---
artifact: CHANGES
feature: 10-ingame-flow-nav
role: Implementer
status: draft
updated: 2026-06-20
inputs: [PLAN.md, harness/state/STATE-CHANGE-02-ingame-flow-nav.md, harness/ux/UX-CHANGE-02-ingame-flow-nav.md, src/shell/game_flow.gd, src/combat/town_view.gd, src/combat/combat_view.gd, src/core/combat/progression_controller.gd, src/core/combat/combat_arena.gd, src/core/game_controller.gd]
next: Engine Integrator
---

# CHANGES · 10-ingame-flow-nav(游戏内板块流程收编 + 城镇枢纽落点 + 待回城)

落地 PLAN.md 八步,实现 STATE-CHANGE-02 / UX-CHANGE-02 目标态:EXPLORE↔TOWN 进出城收进 GameFlow
单一发起点、落点反转为「城镇枢纽(暂停)」、加「出征选关→出击」与「待回城(本波结算才返城)」、城镇升
枢纽 + 四子板块。**无新依赖、无新结构**(沿用 REFACTOR-05 协调器模式),掉落暂存仍 scope OUT。

## 1. What changed(按文件)

### `src/core/combat/progression_controller.gd`(步骤 1 · M1 信号)
- 新增 `signal wave_boundary_settled`(在 `rest_requested` 后)。
- 「包裹法」:现 `advance_after_wave()` 函数体改名私有 `_advance_after_wave_impl()`;公有
  `advance_after_wave()` = 调 impl 后 `wave_boundary_settled.emit()`。`retreat_after_wipe()` 同法
  (抽 `_retreat_after_wipe_impl()` + emit)。两条波界路径都发且只发一次,**CombatArena 调用名零改面**。

### `src/combat/town_view.gd`(步骤 2 / 5 / 7 · 纯视图枢纽,整文件重写)
- 退为纯视图执行器:新增 `show_town()`(显本视图 + 隐兄弟 CombatView + 复位枢纽层 + 刷新,**不碰
  `running`**)、`show_combat()`(隐本视图 + 显 CombatView)。删除原 `_enter_town`/`_leave_town`/
  `reset_to_combat` 及其中所有 `pause_run`/`resume_run` 调用(进出城决策上移 GameFlow)。
- 枢纽化:`enum Board { HUB, PARTY, SMITH, TAVERN, DEPART }` + `_show_board()` 切枢纽层与四覆盖式
  overlay 的 `.visible`(非 Flow 态)。枢纽层 = 标题 + 进度速览 `_hub_progress` + [☰] + 四入口钮。
- 四子板块:**小队**(选槽 + 背包换装 + 各轴差值绿↑红↓,复用原换装/对比逻辑)、**工匠**(选槽 +
  强化 +1,复用原 `enhance_item` 逻辑)、**酒馆**(占位"敬请期待")、**出征**(`_rebuild_depart`:
  主钮「继续当前进度」→ `gf.on_depart(-1,-1)`;每关钮 i≤max_unlocked_stage 可点 → `gf.on_depart(i,0)`)。
- 供 GameFlow 的 Esc 查询/收起:`is_overlay_open()` / `close_overlay_to_hub()`。
- 跨层取 GameFlow 走 group `game_flow`(`_game_flow()`),[☰] → `gf.open_menu(GameFlow.Return.TOWN)`。

### `src/shell/game_flow.gd`(步骤 3 / 4 / 5 / 7 · 流程主导)
- 新增 `var _return_pending := false`(待回城寄存器)。
- 新增 `_enter_town_hub()`(落点反转):`_flow=TOWN` + `_gc.pause_run()` + TownView `show_town()` +
  `enter_game_geometry()`。`on_continue()`(TITLE 分支)与 `_do_new_game()` 改调它(替原 `_enter_game()`)。
- `_ready` 连 `_gc.progression.wave_boundary_settled` → `_on_wave_boundary_settled()`(null 守卫)。
- 新增转移:`on_depart(stage, scene)`(守 `stage<=max_unlocked_stage`;`<0`→`resume_run` 续战,
  否则 `begin_run(stages,stage,0)`;再 `show_combat()` + `_flow=EXPLORE`)、`on_request_return()`
  (EXPLORE 下切 `_return_pending`,再点撤销/R3,**不碰 running**)、`is_return_pending()`、
  `_on_wave_boundary_settled()`(EXPLORE 且 pending → `call_deferred("_return_to_town_deferred")`,
  避 tick 内重入/D5)、`_return_to_town_deferred()` = `_enter_town_hub()`。
- `_unhandled_input` 加 TOWN-Esc 分支:子板块开 → `close_overlay_to_hub()`;在枢纽 → `open_menu(TOWN)`
  (Esc 权威集中 GameFlow / R4)。
- 删除已死代码 `_enter_game()` 与 `_reconcile_views_to_combat()`(后者调的 `reset_to_combat` 已随
  TownView 重写删除,守"不留未用代码")。

### `src/combat/combat_view.gd`(步骤 6 · 探索回城钮)
- 新增 `_return_btn`「回城」:`pressed` → `_on_return_pressed()` → `gf.on_request_return()`(惰性
  `_game_flow()` getter,因 CombatView._ready 早于 GameFlow 入组);`_on_menu_pressed` 同改用该 getter。
- `_update_progress_and_buttons()` 据 `gf.is_return_pending()` 切按钮文案(回城 / 已请求回城·本波后返),
  **不暂停、不改战斗其余态**。

## 2. Why(映射 PLAN 步骤/决策)
- 步骤 1 = D1 包裹法;步骤 2 = D2 GameFlow 主"何时"+ TownView 主"如何";步骤 3 = D3 落点反转;
  步骤 4 = D5 `_return_pending` + 延迟返城;步骤 5 = D4 `on_depart` 守 `max_unlocked_stage`;
  步骤 6 = 探索回城钮 + 已请求态;步骤 7 = D6 四 overlay + R4 Esc 集中 GameFlow。

## 3. How verified
- `godot --headless --import`:全脚本编译通过,0 Parse Error(修一处 `town_view.gd:270` `nm` 类型推断)。
- gdUnit4 全量:**158 test cases · 0 errors · 0 failures · 0 orphans · PASSED**(含新增
  `wave_boundary_settled_test.gd` 2 用例:波清空 / 团灭各发信号恰 1 次;旧用例零回退)。
- 表现层(GameFlow / TownView / CombatView 为 Control 节点)= 手动 Play 验收,见 §6 清单(交作者/EI 跑)。

## 4. Deviations(与 PLAN 的偏差,同范围)
- **TownView 三步合一次重写**:PLAN 步骤 2/5/7 分述 TownView 改动,落地时合并为单次整文件 Write
  (枢纽重组 + 纯视图方法 + 出征 overlay 强耦合,增量编辑churn 大)。范围不变,仅落码方式。
- **Esc 权威取 R4 退路而非主路**:PLAN 步骤 7 主路 = TownView `_unhandled_input` 先吃子板块 Esc。
  落地采 R4 明示的退路 —— Esc 裁决全集中 GameFlow `_unhandled_input`(查询 `tv.is_overlay_open()` /
  `tv.close_overlay_to_hub()`),因 GameFlow 为树末节点必最先收 Esc,避免与 TownView 抢吃的传播顺序脆弱性。
- **回城钮文案**:用「已请求回城 · 本波后返」(PLAN 示例文案的等义精简),语义一致。

## 5. Wiring Contract(交 Engine Integrator)
**无 .tscn / .tres / 资源导入改动 —— 全部为既有节点上的脚本行为变更,无需在编辑器接线。**

- **节点与 group(均已存在,无需新建/改名)**:
  - `GameFlow`(`scenes/shell/floating_shell.tscn` 末子节点,group `game_flow`,`@export stages` 已拖
    `stage_01.tres` / `stage_02.tres`)—— 维持现状,本次不改场景。
  - `TownView`(MainArea 下,`_ready` 自注 group `town_view`)、`CombatView`(MainArea 下,名
    "CombatView",TownView 以 `get_parent().get_node_or_null("CombatView")` 取兄弟)—— 维持现状。
  - autoload `Game`(`/root/Game`)、`Player`(`/root/Player`)顺序不变。
- **新增运行时信号连接(代码内完成,非编辑器)**:`GameFlow._ready` →
  `Game.progression.wave_boundary_settled.connect(_on_wave_boundary_settled)`。依赖 `Game.progression`
  在 GameFlow `_ready` 前已建(GameController boot 内 `new`,autoload 先于场景 `_ready`)—— 已成立。
- **跨节点公有 API 约定(供手测/EI 核对)**:
  - GameFlow 暴露:`on_depart(stage:int, scene:int)`、`on_request_return()`、`is_return_pending()->bool`、
    `open_menu(GameFlow.Return)`。
  - TownView 暴露:`show_town()`、`show_combat()`、`is_overlay_open()->bool`、`close_overlay_to_hub()`。
  - CombatView「回城」钮与 TownView 出征钮均经 group `game_flow` 调上述 GameFlow API,无写死路径。
- **验证命令**(EI 可复跑):
  - 解析:`"G:\Godot\Godot_v4.6.3\godot.exe" --headless --import`(应 0 Parse Error)。
  - 单测:`"G:\Godot\...\godot.exe" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`(应 0 failures)。
    注:gdUnit4 在 headless 须带 `--ignoreHeadlessMode`;`runtest.cmd` 需 `--godot_binary <exe>` 或 `GODOT_BIN`。

## 6. 手动验收清单(表现层 · 交作者按 Play 回报,EI 据此收口)
1. 启动 →（主菜单）「新游戏」→ **落城镇枢纽且挂机暂停**(战斗不自动跑);「继续」(有档)同样落城镇暂停。
2. 城镇枢纽四入口(小队/工匠/酒馆/出征)可点 → 各 overlay 打开、「← 返回枢纽」可回;子板块开时 Esc 退回枢纽。
3. 枢纽根按 Esc → 开主菜单(MENU_OVERLAY);继续 → 回城镇且维持暂停。[☰] 全局入口仍可用。
4. 出征 → 见已解锁关列表(未解锁置灰)→「继续当前进度」或选关「出击」→ 切探索、对应关开打(running)。
5. 出击当前关前,在小队换装 / 工匠强化 → 出击后改动在战斗里生效(resume_run 重快照)。
6. 探索中「回城」钮可见 → 点击转「已请求回城·本波后返」、战斗**不立即停** → 本波结算(清空或团灭)→
   切回城镇枢纽且暂停;再点回城(标记态)→ 撤销、按钮复原、继续挂机。

## 7. Flags(滚给下游)
- **F-R5(deferred pause 前 ≤1 tick 过冲)**:返城在波界信号后 `call_deferred`,本帧累积剩余 tick(常 0–1)
  可能在新波多跑一两步。PLAN 已接受;若 playtest 觉察,在 `CombatArena._process` while 内复查 `running`(小改)。
- **F-R3(待回城可撤销)**:实现了「再点回城撤销」。若 GD 定「出征即承诺不可撤」→ 删
  `on_request_return()` 撤销分支即可(一行)。
- **F-scope**:四子板块一块做完(出征新增 + 小队/工匠复用 + 酒馆占位);未拆 10b。
- **下游 doc**:STATE-MACHINES.md 的 `[SC-02 计划]` / UX-MAP 待由后续 role 把"计划"转"现状"、关 §6.4 双发起点债。
- **scope OUT 未动**(确认):掉落暂存(arch-guard)、掉落预览收窄(UI 轮)、工匠分解/制作(GD)、酒馆招募
  (Producer Later)、RESTING/GameOver 出口。

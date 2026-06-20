---
artifact: PLAN
feature: 10-ingame-flow-nav
role: Planner
status: draft
updated: 2026-06-20
inputs: [project-context.md, STATE-MACHINES.md, ARCHITECTURE.md, harness/state/STATE-CHANGE-02-ingame-flow-nav.md, harness/ux/UX-CHANGE-02-ingame-flow-nav.md, src/shell/game_flow.gd, src/combat/town_view.gd, src/combat/combat_view.gd, src/core/combat/progression_controller.gd, src/core/combat/combat_arena.gd, src/core/game_controller.gd]
next: Implementer
---

# PLAN · 10-ingame-flow-nav(游戏内板块流程收编 + 城镇枢纽落点 + 待回城)

## 1. Goal
把 EXPLORE↔TOWN 进出城收进 GameFlow 单一发起点、落点反转为「城镇枢纽(暂停)」、加「出征选关→出击」与「待回城(本波结算才返城)」转移,城镇升为枢纽 + 四子板块(出征新增 / 小队·工匠复用现有 / 酒馆占位),落成 STATE-CHANGE-02 的目标态。

## 2. Approach & key decisions

> 落地 STATE-CHANGE-02 的 M2/M1 delta。**核心结论沿用 SMM:不新增 Flow 态**——只搬两条边进 GameFlow + 翻落点 + 加 `_return_pending` 寄存器 + M1 `wave_boundary_settled` 信号。掉落暂存 scope OUT(见 §4)。

- **D1 — `wave_boundary_settled` 用"包裹法"发,保证每条波界路径都发且只发一次。**
  `advance_after_wave()` 有 4 条 `return` 分支(GRINDING-push / GRINDING-rest / GRINDING-spawn / BOSS-countdown / 普通场景),在"尾行"加 emit 只覆盖最后一条。故把现有 `advance_after_wave` 函数体抽成私有 `_advance_after_wave_impl()`,公有 `advance_after_wave()` = 调 impl 后 `wave_boundary_settled.emit()`;`retreat_after_wipe()` 同法包裹。**CombatArena 调用名不变**(`progression.advance_after_wave()` / `retreat_after_wipe()`),零改面。
  - *为何不在 CombatArena 发*:信号语义"一个波界已结算"属 M1 职责(STATE §3.2),M1 owns it;CombatArena 只是触发点。
  - *拒绝*:在每个 return 前各加一行 emit —— 易漏分支、加新分支必再漏(STATE §6.2 散转移债的同款陷阱)。
- **D2 — GameFlow 拥有"何时切板块",TownView 拥有"怎么切视图";这才真正关掉 §6.4 / ARCH §6 双发起点债。**
  现状双发起点 = GameFlow(菜单几何)和 TownView(进出城 pause/resume + 自他显隐)各自发起可见性变更。改为:**进出城的决策(pause/resume + flow 转移)全部上移 GameFlow**;TownView 退为纯视图执行器,暴露 `show_town()` / `show_combat()`(view-only,不碰 `running`),由 GameFlow 命令。TownView 内部仍负责切自身 `_town_root` + 兄弟 `CombatView` 的 `.visible`(沿用现 `reset_to_combat()` 已有的纯视图模式,REFACTOR-05 协调器边界内,**无新结构**)。
  - *为何不引 ScreenManager*:v1 两视图 + 城镇内 overlay 用 `.visible` 可承(STATE-CHANGE-02 §5 判定);引屏容器 = arch 事,scope OUT。
- **D3 — 落点反转:continue/new_game → `begin_run`/`new_game` → `pause_run()` → 显城镇枢纽。**
  现 `_enter_game()` 落 EXPLORE(running=true 自动战斗)。改为新增 `_enter_town_hub()`:`pause_run()` 后令 TownView `show_town()`,`_flow=TOWN`,几何仍 `enter_game_geometry()`(底部 strip,非菜单几何)。`Flow.TOWN` 由孤儿态转正式落点。
  - *已记权衡*:有意接受支柱 1"启动即陪伴"让位(UX §3.2,用户拍板),非漏做。
- **D4 — 出征「出击」= `GameFlow.on_depart(stage, scene)`,据是否换关走 `resume_run` 或 `begin_run(选关)`。**
  守卫:`stage <= progression.max_unlocked_stage`(只能打已解锁关)。选当前游标关 → `resume_run()`(吃城镇换装/强化改动,夹 hp);选他关 → `begin_run(stages, stage, scene)`(重装该关);再令 TownView `show_combat()`,`_flow=EXPLORE`。
  - *为何 GameFlow 持有 stage 参*:GameFlow 已 `@export stages`,且 `begin_run` 早已支持显式 `stage/scene`(game_controller.gd:74),只是此前没被选关喂过。
- **D5 — 待回城用 `_return_pending: bool` 寄存器 + 延迟到 `wave_boundary_settled` 才 pause;返城动作 `call_deferred` 避免 tick 内重入。**
  `on_request_return()`:`_flow==EXPLORE` 且 `not _return_pending` → 置 `_return_pending=true`(**不碰 running**,战斗续跑,守支柱 1 / 不变量 #12);再调 = 撤销(置 false,见 R3)。GameFlow 监听 `wave_boundary_settled`:若 `_return_pending` → `_return_pending=false` 后 `call_deferred("_enter_town_hub_from_explore")`(该延迟函数做 `pause_run()` + `show_town()` + `_flow=TOWN`)。
  - *为何 deferred*:`wave_boundary_settled` 在 `CombatArena.tick_combat()` 内同步发(arena 自己的 tick 中)。若 handler 同步 `pause_run()`(含 `_sync_party_equipment`),= 在 arena tick 内重入改其状态。deferred 到 idle 帧执行,等本 `_process` 完全退栈,杜绝重入。
  - *已知小瑕疵(接受)*:`_process` 的 while 累加循环(combat_arena.gd:93)不在循环内复查 `running`,故 deferred pause 落地前,本帧累积的剩余 tick(常态 0–1 个)可能在新刷的波上多跑一两步。v1 可接受(返城本就 `pause_run` 重快照夹 hp);若 playtest 觉察再收紧(R5)。
- **D6 — 城镇枢纽 = 入口按钮 + 四覆盖式 overlay(`.visible` 切换),不为子板块开 Flow 态。**
  TownView 重构为:枢纽层(四入口:工匠/小队/酒馆/出征 + 进度速览)+ 四个 overlay 子面板。**小队** = 现有换装+对比(`_rebuild_slots`/`_rebuild_compare` 的选槽+背包换入+绿↑红↓);**工匠** = 现有强化 +1(`_rebuild_compare` 的强化行+按钮);**出征** = 新增已解锁关列表→「出击」;**酒馆** = 占位("敬请期待"+返回)。子面板共用现有渲染件,只是分面板呈现。`_flow` 恒为 TOWN。
  - *为何复用而非全新左仓右详情*:UI/juice 全局推迟一轮(项目铁律);本块只立 IA 骨架 + 接通导航,精修留 UI 轮。
  - *拒绝*:给四子板块各开 Flow 态(TOWN_SMITHY/…)—— STATE-CHANGE-02 §6 判过度建模,M2 只认"在不在城镇"。
- **D7 — 测试分层:M1 信号 = gdUnit4 纯逻辑回归;GameFlow/TownView 流程 = 手动 Play 验收。**
  按 project-context §1:只测纯逻辑,表现层(Control 节点)靠手动。`wave_boundary_settled` 在 RefCounted 的 ProgressionController 上,可单测;GameFlow 转移走 ACCEPTANCE 手验清单。

## 3. Ordered steps

1. **M1 加 `wave_boundary_settled` 信号(包裹两个波界落点)。**
   - 文件:`src/core/combat/progression_controller.gd`。
   - 做:声明 `signal wave_boundary_settled`;把现 `advance_after_wave()` 函数体改名 `_advance_after_wave_impl()`,新 `advance_after_wave()` = `_advance_after_wave_impl()` 然后 `wave_boundary_settled.emit()`;`retreat_after_wipe()` 同法(抽 `_retreat_after_wipe_impl()` + emit)。CombatArena 调用名不动。
   - 验证:`godot --headless --check-only` 过;新 gdUnit4 用例:连 `wave_boundary_settled`,`begin_run` 后喂一波清空(模拟 advance_after_wave 调用路径)断言信号发了 1 次;团灭路径(retreat_after_wipe)断言发 1 次;无监听者时既有 153 测全绿(信号 no-op)。

2. **TownView 抽出纯视图方法 `show_town()` / `show_combat()`,进出城决策权交还 GameFlow。**
   - 文件:`src/combat/town_view.gd`。
   - 做:新增 `show_town()`(= `_town_root.visible=true` + 隐兄弟 `CombatView` + `_refresh()`,**不调 `pause_run`**)、`show_combat()`(= 现 `reset_to_combat()` 内容:`_town_root.visible=false` + 显 CombatView;可直接复用/合并 `reset_to_combat`)。删除 `_enter_town`/`_leave_town` 里的 `_gc.pause_run()`/`resume_run()` 调用(决策上移);删除独立「进城」按钮(落点即城镇,无需进城入口);原「出城」按钮逻辑并入出征「出击」(步骤 5)。
   - 验证:check-only 过;TownView 不再出现 `pause_run`/`resume_run` 字样(grep 确认决策已上移);手动:暂不接 GameFlow 时该步可能短暂无法进出城,接续步骤 3-5 后整体验。

3. **GameFlow 落点反转:新增 `_enter_town_hub()`,continue/new_game 落城镇枢纽(暂停)。**
   - 文件:`src/shell/game_flow.gd`。
   - 做:加私有 `_enter_town_hub()`:`_hide_all_screens()` → `_gc.pause_run()` → 取 TownView(group `town_view`)调 `show_town()` → `_flow=Flow.TOWN`,`_menu_return_to=Return.NONE` → `_shell.enter_game_geometry()`。改 `on_continue()`(TITLE 分支)与 `_do_new_game()`:`begin_run`/`new_game` 后改调 `_enter_town_hub()`(替原 `_enter_game()`)。保留 `_enter_game()` 供他处复用或删之(若无引用则删,守"不留未用代码")。
   - 验证:check-only 过;手动 Play:启动→主菜单→「新游戏」→ **落城镇枢纽且挂机暂停**(战斗不自动跑);「继续」(有档)同样落城镇暂停;`[☰]`→主菜单→继续 仍回城镇且维持暂停(`_resume_to_source` 不变)。

4. **GameFlow 监听 `wave_boundary_settled` + `_return_pending` 寄存器 + 回城/撤销转移。**
   - 文件:`src/shell/game_flow.gd`。
   - 做:加 `var _return_pending := false`;`_ready` 里 `_gc.progression.wave_boundary_settled.connect(_on_wave_boundary_settled)`(null 守卫)。加 `on_request_return()`:仅 `_flow==EXPLORE` 时有效,`not _return_pending`→置 true、`_return_pending`→置 false(撤销)。加 `_on_wave_boundary_settled()`:`if _flow==EXPLORE and _return_pending: _return_pending=false; call_deferred("_return_to_town_deferred")`。加 `_return_to_town_deferred()`:`pause_run()` + TownView `show_town()` + `_flow=TOWN`。
   - 验证:check-only 过;手动 Play(需步骤 5 的回城按钮接好后整体验):探索中点回城 → 战斗**不立即停**、按钮转「已请求回城」→ 本波打完(或团灭)瞬间 → 切回城镇枢纽且暂停;再点回城(标记态)→ 撤销、按钮复原、继续挂机。

5. **出征子板块(选关)+ `GameFlow.on_depart` 出击转移。**
   - 文件:`src/combat/town_view.gd`(出征 overlay)、`src/shell/game_flow.gd`(`on_depart`)。
   - 做:TownView 出征 overlay = 列 `0..max_unlocked_stage` 的关卡按钮(读 `_gc.progression.max_unlocked_stage` + `_gc.progression.stages`;未解锁置灰);点关「出击」→ 调 GameFlow `on_depart(stage, scene)`(scene 默认 0;选当前游标关可传 -1,-1 走续战)。GameFlow `on_depart(stage, scene)`:守卫 `stage<=progression.max_unlocked_stage`;`stage<0`(续当前)→ `_gc.resume_run()`,否则 `_gc.begin_run(stages, stage, scene)`;再 TownView `show_combat()`、`_flow=Flow.EXPLORE`、`enter_game_geometry()`。
   - 验证:check-only 过;手动:城镇→出征→见已解锁关列表→选关「出击」→ 切探索、对应关开打(running=true);出征未解锁关置灰不可点;出击当前关时换装/强化改动在战斗里生效(resume_run 重快照)。

6. **探索·回城按钮 + 「已请求回城」态(CombatView)。**
   - 文件:`src/combat/combat_view.gd`。
   - 做:加「回城」按钮,`pressed` → 经 group 取 GameFlow 调 `on_request_return()`;按 GameFlow `_return_pending`(经只读查询或 GameFlow 回调)切按钮文案:`default`="回城" / `已请求`="已请求回城,本关结束后返回"。**不暂停、不改战斗其余态**。(掉落预览面板的收窄见 §4 OUT,本步不动现 `_panel`。)
   - 验证:check-only 过;手动:探索中「回城」按钮可见、点击进入「已请求回城」文案、本波结算后返城(与步骤 4 联验);未请求时按钮常态。

7. **城镇枢纽骨架 + 四入口 overlay + Esc 层级。**
   - 文件:`src/combat/town_view.gd`。
   - 做:把现单层 town 内容重组为「枢纽层(四入口按钮:工匠/小队/酒馆/出征 + 进度速览)+ 四 overlay 子面板」。小队 overlay=选槽+换装+对比;工匠 overlay=选槽+强化;出征 overlay=步骤 5 列表;酒馆 overlay=占位+返回。子面板 `.visible` 切换,各带「返回枢纽」。Esc:子面板开着→ TownView `_unhandled_input` 关子面板回枢纽并 `set_input_as_handled()`;枢纽根(无子面板开)→ 不吃 Esc,让 GameFlow 收到→ `open_menu(Return.TOWN)`(城镇是游戏内根,Esc 给键盘一条通系统枢纽的出口)。
   - 验证:check-only 过;手动:城镇枢纽四入口可点→各 overlay 打开/返回正常;子面板开时 Esc 退回枢纽;枢纽根按 Esc → 开主菜单(MENU_OVERLAY)、继续回城镇暂停;`[☰]` 全局入口仍可用。

8. **回写状态文档 + 走完整验证流程。**
   - 文件:无代码(文档);跑 §5 流程。
   - 做:确认 STATE-MACHINES.md 的 `[SC-02 计划]` 行已与落码一致(SMM 已先行标注,落码后由后续 role 把 `[SC-02 计划]`/`🔜` 转「现状」、关 §6.4 债);更新 HANDOFF。
   - 验证:`godot --headless --check-only` 全绿 → gdUnit4 全绿(含步骤 1 新用例,旧 153 不退)→ 手动 Play 走通:启动→城镇枢纽(暂停)→出征选关出击→探索挂机→回城(待回城→波结算返城)→换装/强化→再出击 全链路。

## 4. Out of scope（本块不做,明确划走)
- **掉落暂存区 + 结算唯一写入口**:现 `loot_intake.gd` 敌死即时写 `PlayerState`(combat_arena.gd:193)。UX §3.4 的「暂存→结算合并」= 新数据结构 + 写时机不变量(#4/#11)改写,**属 arch-guard,且待回城不依赖它**(STATE-CHANGE-02 §5)。要做单独 `/arch-guard 10-ingame-flow-nav`。
- **掉落预览面板收窄到「掉落装备+材料」**:现 `combat_view.gd` 的 `_panel`(掉落包+当前装备+8 维属性)保持原样,仅探索 HUD 加回城按钮;把面板改成只读掉落+材料速查 = UI 内容调整,并入全局 UI·juice 轮(本块只接导航,不动面板内容)。
- **工匠·分解/制作 新机制**:本块工匠 overlay 只承现有「强化 +1」;分解/制作 = 新玩法,flag Game Designer。
- **酒馆招募内容**:只接 nav 入口 + 占位屏,招募 = Producer scoped Later。
- **出征「选关」是否改变挂机推关心智**:本块 = 选已解锁关→仍是关内 idle 自动战斗(不改 ProgressionController 推进逻辑);"选关 vs 自动推关"的玩法心智 = Game Designer 旋钮。
- **左仓库/右详情精排、出击/回城按钮视觉、城镇"家"视觉权重、待回城结算粒度调参** = Art Spec UI·juice 轮 + GD 旋钮。
- **RESTING 死胡同出口、GameOver 态、两套"停"语义统一**(STATE §6.3/§6.6)= 本块不碰。

## 5. Risks & Flags / Open questions
- **Flag(scope·给 Producer)——四子板块工作量是否需再切片?** 本 PLAN 取「navigation 主体 + 最小可用枢纽」:出征(新)+ 小队/工匠(复用现有换装/强化)+ 酒馆(占位)。**推荐:整块一次做**(子板块多为现有内容重组,新增主要是出征列表 + 回城 + 落点,blast radius 受控)。若 Producer 仍想拆,可把「步骤 7 枢纽+四 overlay 重构」单独切为 10b,先落 1-6(状态机骨架 + 落点 + 出征 + 待回城),城镇暂留现单层 + 一个临时「出击」按钮。两条路 SMM 状态机 delta 都成立。
- **R1(待回城粒度)——波 vs 场景 vs 关**:本案默认「波界」(波清空/团灭都触发,卡关也能及时返城)。是否要"打完整关才回" = GD 旋钮,留 `_return_pending` + 信号 guard 可收紧,不阻塞本块。
- **R2(收编爆炸半径)**:GameFlow 横向命令 TownView/CombatView 显隐沿用 09/REFACTOR-05「协调器调公开 API」模式,**无新结构**(STATE-CHANGE-02 §5 判定)。若 Implementer 落地中发现 `.visible` 横向调撑不住、需屏容器/ScreenManager → STOP 转 `/arch-guard`(勿在 Implementer 层硬塞结构)。
- **R3(待回城可撤销?)**:步骤 4 给了"再点撤销"。若 GD 认为"出征即承诺不可撤"→ 删 `on_request_return` 的撤销分支即可(纯一行,两种都支持)。flag GD。
- **R4(Esc 双吃)**:子面板 overlay 的 Esc(TownView 关子面板)与 GameFlow `_unhandled_input` 的 Esc 需定优先级 = **子面板开着时 TownView 先吃 + `set_input_as_handled()`**(步骤 7)。Implementer 落地时确认 `_unhandled_input` 传播顺序符合预期(Godot 中后入/更深节点先收);若顺序不稳,改用 `_input` + 显式判 town 子面板可见性。
- **R5(deferred pause 前的 ≤1 tick 过冲)**:见 D5。v1 接受;若 playtest 觉察返城瞬间新波被多打一两下,再在 `CombatArena._process` while 循环内复查 `running`(小改),本块先不动。
- **手动验收依赖**:GameFlow/TownView 为表现层,核心流程靠 §5 手动 Play(纯 vibe coding,作者按 Play 回报)。步骤 1 的 M1 信号是唯一可单测项;务必把它做实,作为整链路唯一自动回归锚。

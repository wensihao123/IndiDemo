---
updated: 2026-06-20
---

> ✅ **STATE-CHANGE-01 已落地(2026-06-20,09-title-main-menu)**:M2 已升为显式 `GameFlow` 流程机
> (`enum Flow{BOOT,TITLE,EXPLORE,TOWN,MENU_OVERLAY}` + 来源寄存器 `menu_return_to`),M3 已加 `MENU`
> 几何态。归宿 = 表现层 `GameFlow` 协调节点(`src/shell/game_flow.gd`,REFACTOR-05)。人手动 Play 验收
> + 代码评审(APPROVE WITH NITS)通过、156/156 测绿。下列 M2/M3/§5/§6.4 已由 🔜 转**现状**。
>
> 🔜 **STATE-CHANGE-02 已起草(2026-06-20,10-ingame-flow-nav,status: draft → Planner)**:把
> EXPLORE↔TOWN 进出城**收进 GameFlow**(关掉 §6.4 残留 / ARCHITECTURE §6 双发起点债)、落点改 **TOWN
> 枢纽(暂停)**、加「出征(选关)→出击」与「待回城」转移。**不新增 Flow 态**;delta = 2 条边迁入
> GameFlow + 落点翻转 + 新寄存器 `_return_pending:bool` + M1 新信号 `wave_boundary_settled`。下面 M2/M1/§5/§6.4
> 标 `[SC-02 计划]` 的行 = **目标态、尚未落码**,以代码为准前仍是 STATE-CHANGE-01 现状。详见
> `harness/state/STATE-CHANGE-02-ingame-flow-nav.md`。

# STATE-MACHINES — test-2 (2D 横版挂机 ARPG)

> 项目的**状态机事实源**(State Machine Master 维护)。它描述项目里**动态行为**:有哪几台
> 有限状态机、各自的状态 / 事件 / 转移 / 守卫。与 [[ARCHITECTURE]](静态结构:数据模型 / 模块
> 边界)配套——那边管"系统**是**什么、谁依赖谁",这边管"系统在时间里**怎么变**"。
>
> ⚠ **本文 v1 = 逆推自现有代码(2026-06-20),反映现状、不是理想形态。** 项目已深度开发(153
> 测试绿、四层地基),但此前从未建过状态机事实源。下面记录的是真实代码里**实际存在**的机(含
> 隐式靠布尔标志硬撑的),"该长什么样"的重构留给后续模式 B。已知混乱全记入 §6 状态债。

## 1. 状态管理一句话 / Overview

当前**仍无统一的 FSM 基类**,但风格在收敛:四台机——两台规整 enum 单点变更
(`floating_shell.State`、本次落地的 `GameFlow.Flow`)、一台 enum 但转移散落多方法
(`ProgressionController.mode`,项目核心机)、一台裸布尔运行开关(`CombatArena.running`)。
M2 游戏流程已由"隐式布尔"升为显式 `GameFlow` 流程机(STATE-CHANGE-01,债 §6.4 闭合);M4 仍是裸 bool。
**[SC-02 计划]** EXPLORE↔TOWN 进出城将从 `TownView` 自管收进 GameFlow(§6.4 残留随之关闭),落点改 TOWN
枢纽暂停,加 `_return_pending` 寄存器承"待回城"——仍不新增 Flow 态。
逻辑层全 headless 可演算、固定步长 tick 驱动(承不变量 #3);表现层只读状态、不持有逻辑状态。
**理想方向**(部分到位):一套规范 enum + 集中转移派发 + "转移是改状态的唯一途径"——M1/M3/`GameFlow`
已是单点变更或集中转移,仅 M4 仍裸布尔,见 §6。

## 2. 状态机清单 / Machine inventory

| 机 | 载体 | 形态 | 作用域 | 嵌套 |
|----|------|------|--------|------|
| **M1 进度推进机** | `ProgressionController.mode`(enum `Mode`) | **显式 enum**(项目核心机) | per-run:跨场景推进 / 卡关 / 通关倒计时 / 修整 | 嵌在 M2.Combat 内;带子寄存器 `_queued:QueuedAction` |
| **M2 游戏流程机** | `GameFlow._flow`(enum `Flow`)+ 来源寄存器 `_menu_return_to`(enum `Return`);**[SC-02 计划]** 加 `_return_pending:bool`(待回城)、进出城转移迁入 GameFlow(原 `TownView` 自管的 `pause_run/resume_run`+`.visible` 改由 GameFlow 发起,§6.4 残留关闭) | **显式 enum**(STATE-CHANGE-01 升格) | 顶层:Boot → Title → Game{Explore↔Town} + MENU_OVERLAY | 顶层机;含 M1 + M4;命令 M3 切 MENU↔strip 几何 |
| **M3 悬浮窗外壳机** | `floating_shell._state`(enum `State{EXPANDED,COLLAPSED,MENU}`) | **显式 enum**(最规整) | 窗口表现:展开 / 收起 / 居中菜单窗 | **与 M1/M4 全正交;与 M2 部分正交**——`{EXPANDED,COLLAPSED}` 与 `{EXPLORE,TOWN}` 正交,`MENU` 几何 ↔ TITLE/MENU_OVERLAY 1:1 锁定(见 §3.3/§5#7) |
| **M4 单局运行开关** | `CombatArena.running`(bool)+ `enraged`(单向 latch) | **裸布尔 + latch** | per-run:tick 是否推进 | 与 M1 同层(M4 = tick 闸),受 M2 切换 |

**派生 / 已退化(不算正规机,但属"状态"语义):**
- **Entity 存活态** alive/dead — 由 `current_hp` 派生(`is_alive()`),per-entity,无显式机。
- **AICombatComponent** — ARCHITECTURE §3.1 仍把它写作"轻量状态机:寻敌/接近/进射程/出手",
  但**现实已退化为无状态目标选择**(`select_target` = 集火最前存活);近战门控/远程隔位上移到
  `CombatArena._front_melee_attackers`(阵型级、每 tick 重算,非 per-entity 机)。详见 §6.5。

**嵌套关系:**
```
M2 游戏流程机 GameFlow (顶层)
  ├─ Boot ──(只 _boot,不 begin_run)──> Title(启动落点,几何=MENU)
  ├─ Title ──[继续/新游戏]──> [SC-02: Town 枢纽(暂停)] / [SC-01 现状: Explore(挂机)]
  ├─ Explore:  M4.running=true,M1 活跃驱动刷波/推进
  │     └─[SC-02] 出征(选关)──on_depart──> Explore;待回城──on_request_return──置 _return_pending
  │           ──wave_boundary_settled[_return_pending]──> Town(本关结算后返城,守不变量 #12/支柱 1)
  ├─ Town(城镇):  M4.running=false(pause_run),M1 冻结;[SC-02] = 家/枢纽,新游戏/继续落此
  │     └─[SC-02] 四覆盖式子板块(工匠/小队/酒馆〔占位〕/出征)= 视图内 overlay,非 M2 态(_flow 仍 TOWN)
  └─ MENU_OVERLAY([☰] 调出):  几何=MENU,**不动 M4.running**(菜单不暂停 sim);记 _menu_return_to
M3 悬浮窗外壳机  ── EXPANDED/COLLAPSED 与游戏态正交(任意游戏态可展开/收起,守不变量 #3);
                   MENU 几何与 Title/MENU_OVERLAY 1:1 锁定(由 GameFlow 命令切换)
```

## 3. 每台机的状态与转移 / States & transitions per machine

### M1 进度推进机 `ProgressionController.mode`(核心机)

状态 `enum Mode { PROGRESSING, GRINDING, STAGE_CLEAR_COUNTDOWN, RESTING }`
子寄存器 `enum QueuedAction { NONE, PUSH, REST }`(仅 GRINDING 内有意义,入队玩家宏操作)
游标 `cur_stage / cur_scene`(场景 0/1/2 = 普通,3 = `BOSS_SCENE`);`max_unlocked_stage` 单调不减。

事件来源:`advance_after_wave`(Arena 在 `not _has_living(enemies)` = **波清空**时调)、
`retreat_after_wipe`(团灭)、`register_kill`(单只敌死,只计数不转移)、`request_push/request_rest`
(玩家)、`process_countdown`(Arena tick 驱动倒计时)、`begin_run`(开局/续战重置)。

**[SC-02 计划] 新增信号 `wave_boundary_settled`**:在 `advance_after_wave` 与 `retreat_after_wipe`
**尾部**(波边界结算完成后)各发一次。M1 保持城镇无关——它只广播"一个波边界已结算",由 M2/GameFlow
据 `_return_pending` 决定是否返城。粒度 = 波边界(默认;关 vs 波的结算粒度 = Game Designer 旋钮)。
不改 M1 任何状态/转移,纯加观测信号(M1 mode 表不变)。

| from | 事件 | 守卫 | to | 动作 |
|------|------|------|----|------|
| (任意) | `begin_run` | — | PROGRESSING | 置游标(越界夹回末关 Boss)、`max_unlocked=max(..)`、刷当前波 |
| PROGRESSING | `wave_cleared` | `cur_scene==BOSS_SCENE` | **STAGE_CLEAR_COUNTDOWN** | `max_unlocked=max(.,stage+1)`、`boss_cleared.emit`、回血、设 `advance_target`(有下关→下关头/末关→本关 Boss)、`countdown=len` |
| PROGRESSING | `wave_cleared` | 普通场景 & `_kills_this_scene>=kill_count` | PROGRESSING | `cur_scene+1`(末场景→BOSS_SCENE)、回血、刷波 |
| PROGRESSING | `wave_cleared` | 普通场景 & 未达标 | PROGRESSING | 仅刷波(补刷同场景) |
| PROGRESSING | `party_wiped` | — | **GRINDING** | 团灭回退游标(四规则)、设 `advance_target`、回血、刷波 |
| GRINDING | `request_push` | — | GRINDING | `_queued=PUSH`(入队,本轮结束执行) |
| GRINDING | `request_rest` | — | GRINDING | `_queued=REST` |
| GRINDING | `wave_cleared` | `_queued==PUSH` | **PROGRESSING** | `_execute_push`:跳 `advance_target`、刷波 |
| GRINDING | `wave_cleared` | `_queued==REST` | **RESTING** | `_enter_rest`:清空敌人、`rest_requested.emit` |
| GRINDING | `wave_cleared` | `_queued==NONE` & 达标 | GRINDING | 回血、刷波(无尽刷) |
| GRINDING | `wave_cleared` | `_queued==NONE` & 未达标 | GRINDING | 仅刷波 |
| GRINDING | `party_wiped` | — | GRINDING | 再次回退 |
| STAGE_CLEAR_COUNTDOWN | `process_countdown` | `countdown_remaining<=0` | **PROGRESSING** | `_execute_push` |
| STAGE_CLEAR_COUNTDOWN | `request_rest` | — | **RESTING** | `countdown=0`、`_enter_rest` |
| **RESTING** | (v1 无出口) | — | — | ⚠ 死胡同:无连回 Combat 的转移,见 §6.3 |

注:`register_kill` 在 GRINDING 且 `_queued!=NONE` 时不计数(把推进让给波清空钩子)。

### M2 游戏流程机 `GameFlow._flow`(显式 enum;STATE-CHANGE-01 已落地)

载体 `src/shell/game_flow.gd`(表现层协调节点,FloatingShell 直接子)。
状态 `enum Flow { BOOT, TITLE, EXPLORE, TOWN, MENU_OVERLAY }`;来源寄存器 `enum Return { NONE, EXPLORE, TOWN }`
(`_menu_return_to`,仅 MENU_OVERLAY 内有意义,记"继续回哪个游戏语境",D6:GameFlow 不跟踪城镇态)。
转移方法集中在 GameFlow:`on_continue/on_new_game/_do_new_game/on_open_settings/on_settings_back/
on_quit/on_quit_confirm/on_overwrite_confirm/open_menu/_resume_to_source`。

| from | 事件 | 守卫 | to | 动作(代码现状) |
|------|------|------|----|------|
| (启动) | `GameController._boot` | — | BOOT | 装配 registry/arena/progression、reset 持久根、load 存档(置 `has_save`)、算续战游标 |
| BOOT | `GameFlow._ready`→`call_deferred(_enter_title)` | — | **TITLE** | `_shell.enter_menu_geometry()`(M3→MENU)、显主菜单屏、按 `has_save` 切「继续」可点性 |
| TITLE | `on_continue`(「继续」) | `has_save` | **EXPLORE** ·[SC-02→**TOWN** 枢纽暂停] | SC-01 现状:`Game.begin_run(stages)`+`_enter_game` 收缩贴底直接挂机。**[SC-02]** 改为 `begin_run`→`pause_run`→落 TOWN 枢纽(暂停),点「出击」才开打 |
| TITLE | `on_new_game`(「新游戏」) | `not has_save` | **EXPLORE** ·[SC-02→**TOWN** 枢纽暂停] | SC-01 现状:`_do_new_game`→`Game.new_game(stages)`(0-0 新局+覆盖存档)+`_enter_game`。**[SC-02]** 同上落 TOWN 枢纽(暂停)。有意接受支柱 1"启动即陪伴"让位(UX-CHANGE-02 §3.2) |
| TITLE | `on_new_game` | `has_save` | TITLE(覆盖确认子屏) | 显 `_overwrite_screen`(破坏性二次确认);确定→`_do_new_game`,取消/Esc→回主菜单 |
| TITLE | `on_open_settings` / `on_quit` | — | TITLE(设置/退出子屏) | 显对应子屏;退出确认→`Game.quit_game()`(autosave 后 `get_tree().quit()`) |
| EXPLORE / TOWN | `open_menu(src)`([☰]) | — | **MENU_OVERLAY** | 记 `_menu_return_to=src`、`_shell.enter_menu_geometry()`、显主菜单屏;**不动 `arena.running`**(守支柱 1) |
| MENU_OVERLAY | `on_continue` / Esc | — | **EXPLORE 或 TOWN** | `_resume_to_source`:`_shell.enter_game_geometry()`、隐菜单屏、`_flow=来源`;**不调 begin_run/resume**(来源态原样保留) |
| Explore | 进城(`TownView._enter_town`) | — | **TOWN** | **SC-01 现状**:`Game.pause_run()`+隐 CombatView/显 town_root,EXPLORE↔TOWN 仍由 TownView 自管,未进 GameFlow(见 §6.4) |
| Town | 出城(`TownView._leave_town`) | — | **EXPLORE** | **SC-01 现状**:`Game.resume_run()`(夹 hp 不免费回血)+ 显 CombatView |
| **[SC-02]** TOWN | `on_depart(stage,scene)`(出征·选关→出击) | 关卡 `<=max_unlocked` | **EXPLORE** | 由 GameFlow 发起:选中关→`begin_run(stage,scene)`(切关)或 `resume_run()`(续当前)+ `_enter_game` 收缩贴底;**进出城转移自此归 GameFlow,关闭 §6.4 残留** |
| **[SC-02]** EXPLORE | `on_request_return`(战斗中点回城) | `not _return_pending` | **EXPLORE** | 置 `_return_pending=true`(待回城标记);**不动 `arena.running`**——本关继续打,守不变量 #12/支柱 1 |
| **[SC-02]** EXPLORE | `on_request_return`(再点) | `_return_pending` | **EXPLORE** | 取消标记 `_return_pending=false`(可选,撤回待回城) |
| **[SC-02]** EXPLORE | `wave_boundary_settled`(M1 波边界结算) | `_return_pending` | **TOWN** | 清标记、`Game.pause_run()`+回城枢纽;本关结算后才返(不打断战斗) |
| **[SC-02]** EXPLORE | `wave_boundary_settled` | `not _return_pending` | EXPLORE | 无操作(常态挂机,继续推进) |

⚠ 仍无 `GameOver` 态(团灭=回退刷怪而非结束)。**SC-01 现状**:EXPLORE↔TOWN 的进出城**未收进 GameFlow**,
仍由 `TownView` 经 `pause_run/resume_run`+兄弟 `.visible` 自管(为限本期爆炸半径有意保留,见 §6.4 / ARCHITECTURE §6)。
**[SC-02 计划]**:进出城转移上移到 GameFlow(出征 `on_depart` 出城、`wave_boundary_settled[_return_pending]`
返城),`TownView` 退为视图(只显隐自身),§6.4 残留随之关闭;城镇四子板块为视图内 overlay,不进 M2 态。
完整 SC-01 转移表与 Esc 约定见 STATE-CHANGE-01 §3.1;SC-02 目标态见 STATE-CHANGE-02 §3.1。

### M3 悬浮窗外壳机 `floating_shell._state`(最规整的显式机;STATE-CHANGE-01 加 MENU)

状态 `enum State { EXPANDED, COLLAPSED, MENU }`;正交布尔 `_always_on_top`。
`MENU` = 居中较大菜单窗(`MENU_SIZE := Vector2i(560,400)`,占位值交 Art Spec)。

| from | 事件 | 守卫 | to | 动作 |
|------|------|------|----|------|
| EXPANDED | toggle(F1 / `collapse_btn` / `handle`) | — | COLLAPSED | `_set_state`→淡出→几何跳变到 `_collapsed_rect`(64×64)→切 handle 可见→淡入→降帧到 `fps_collapsed=15` |
| COLLAPSED | toggle(F1 / `handle`) | — | EXPANDED | `_set_state`→淡出→几何跳变到 `_expanded_rect`(全宽×250)→切主区可见→淡入→`fps_expanded=60` |
| EXPANDED / COLLAPSED | `enter_menu_geometry()`(GameFlow 命令) | — | **MENU** | `_set_state(MENU)`→淡出→几何跳变到 `_menu_rect()`(工作区居中 560×400)→隐 strip/main_area/collapse/handle→淡入(保 `fps_expanded`) |
| MENU | `enter_game_geometry()`(GameFlow 命令) | — | **EXPANDED** | 同款淡出→跳变回 `_expanded_rect`→显主区→淡入 |
| MENU | toggle(F1 等收起触发) | `_state==MENU` | (无反应) | `_toggle_collapse` 开头 `if _state==MENU: return`——**MENU 态无收起出口** |
| (任意) | F2 | — | (态不变) | `_toggle_always_on_top`:翻 `WINDOW_FLAG_ALWAYS_ON_TOP` |

特征:状态变量在 `_set_state` 立即翻转,**几何变更延到 Tween 全透明瞬间**(规避 Windows 改窗几何
抖动;MENU 复用同款退路);待机微动(`hero` 正弦浮动)只在 EXPANDED 跑。
`MENU` 几何由 GameFlow 进出 TITLE/MENU_OVERLAY 时**命令**切换(1:1 锁定);`{EXPANDED,COLLAPSED}`
仍与游戏态 `{EXPLORE,TOWN}` 正交(F1 收起仅游戏中可用,MENU 态无 toggle 出口)。转移表见 STATE-CHANGE-01 §3.3。

### M4 单局运行开关 `CombatArena`(裸布尔 + latch)

- `running: bool` — tick 唯一闸(`_process` 仅 running 时累加步长跑 `tick_combat`)。
  `false→true`:`start_battle` / `resume_run`;`true→false`:`pause_run`(进城)。
- `enraged: bool` — **每场单向 latch**:`battle_time>=enrage_threshold` 时 `false→true`(发
  `enemy_enraged`,加成伤害);`start_battle` 复位 `false`。无回退。
- `_battle_restarted: bool` — 非状态,是 tick 内"敌死触发重开战"的重入守卫(防新生敌当 tick 反击)。

## 4. FSM 基础设施与约定 / FSM infrastructure & conventions

- **无统一 StateMachine 基类 / State 节点范式**(债 §6.1)。各机自实现:
  - M1:`enum Mode` + 转移**散在** `advance_after_wave`/`retreat_after_wipe`/`_execute_push`/`_enter_rest`/`begin_run` 多方法,无集中转移表。
  - M3:`enum State` + **单一变更点** `_set_state`(最接近规范模式)。
  - M2:`enum Flow`(`GameFlow`)+ 转移集中在 GameFlow 转移方法(STATE-CHANGE-01 升格;原"无 enum 布尔耦合"已闭合)。
  - M4:裸 bool。
- **驱动**:固定步长 tick——`CombatArena._process(delta)` 累加 `tick_seconds`,每步先
  `progression.process_countdown` 再 `tick_combat`;headless / 后台 / 收起态结算一致(不变量 #3)。
- **跨层用 signal,过去式命名**:`boss_cleared` / `party_wiped` / `enemy_defeated` /
  `enemy_enraged` / `rest_requested` / `item_dropped`;实体内组件直调。
- **状态名 / enum 保留原文**(`Mode.GRINDING` 等),表现层 `match _prog.mode` 读出渲染。

## 5. 关键不变量 / Invariants

1. **每台机恰好一个活跃状态**(M1.mode / M2.`GameFlow._flow` / M3.\_state 单值;仅 M4 由裸布尔组合,见债)。
2. **M1 推进/刷波只在"波清空"触发**(`not _has_living(enemies)`)= ARCHITECTURE 不变量 #12;
   `register_kill` 只计数不推进,故多敌波可逐个清而非杀一只就整波重刷。**[SC-02]** 新信号
   `wave_boundary_settled` 也只在波边界发,故"待回城"返城与推进同粒度——绝不在波中途打断战斗。
3. **`max_unlocked_stage` 单调不减** — Boss 永久解锁,绝不回退。
4. **团灭回退绝不把 `cur_scene` 设回更早关 Boss** — 保 ARCHITECTURE 不变量 #9 续战判别唯一性。
5. **末关 Boss 通后 `advance_target` 指回本关 Boss**(决策 B)——不把游标推到 `stages.size()`(越界空场)。
6. **`M4.running` 是 tick 唯一闸**;城镇暂停 = `running=false`(M2↔M4 耦合);出城重快照夹 hp 不免费回血(ARCHITECTURE 不变量 #11)。
   **[SC-02]** 新游戏/继续落 TOWN 枢纽时即 `running=false`(枢纽暂停),点「出击」(`on_depart`)才 `resume_run/begin_run`
   置 true;"待回城"期间 `running` 不变(本关照打),返城时才置 false。**有意接受支柱 1"启动即陪伴"让位**
   (城镇=家/枢纽,出击才挂机;见 UX-CHANGE-02 §3.2)。
7. **M3 收起/展开与游戏逻辑全正交;MENU 几何与流程态部分正交** — 窗口收起/展开/置顶不影响演算与
   tick(不变量 #3);收起仅降帧+隐表现。STATE-CHANGE-01 后:`{EXPANDED,COLLAPSED}` 与 `{EXPLORE,TOWN}`
   仍全正交,但 `MENU` 几何 ↔ TITLE/MENU_OVERLAY **1:1 锁定**(GameFlow 命令切换,MENU 态无收起出口),
   故 M3 整体由"全正交"降为"部分正交"。**关键:进出 MENU 不暂停 sim**(`open_menu`/`_resume_to_source`
   绝不动 `M4.running`)——菜单覆盖层与收起态同理,守支柱 1 后台推进。
8. **M1.mode / M2.`_flow` 实际只在受控方法内改** — M1 无旁路直写 mode;M2 升显式 enum 后转移集中在
   GameFlow 转移方法内(规范的"转移是改态唯一途径"在 M1/M2 成立);仅 M4 仍是裸布尔,尚未达此标准。

## 6. 已知状态债 / Known state debt

1. **无统一 FSM 范式** — 四台机四种风格(enum+散转移 / enum+集中 / 布尔耦合 / 裸 bool)。加新机或新态无样板可循,易各写各的。
2. **M1 转移逻辑散落多方法** — 没有集中转移表/派发;加一个 mode(如真离线结算态、Boot 前 Title)要改 `advance_after_wave`/`begin_run` 等多处,易漏分支。
3. **RESTING 是 v1 死胡同(stub)** — 进入后清空敌人、发 `rest_requested`,但**无连回 PROGRESSING/Combat 的转移**。`request_rest` 可达 RESTING,却出不来。若"修整"要成可玩态须补出口(可能并入 M2 城镇语义)。
4. **✅【已偿,STATE-CHANGE-01 / REFACTOR-05,2026-06-20】M2 游戏流程已升显式机** — 原靠
   `town_root.visible`+`arena.running`+手动 show/hide 三处耦合,已抽成表现层 `GameFlow` 显式 enum 流程机
   (Boot→Title→Game{Explore↔Town}+MENU_OVERLAY),加 Title/设置/覆盖确认/退出确认四屏 + 统一 Esc。
   §5 不变量 #1/#7/#8 已随之改写。**残留 → 🔜 STATE-CHANGE-02 计划关闭**:EXPLORE↔TOWN 的进出城此前**未收进
   GameFlow**,仍由 TownView 自管(`pause_run`+兄弟 `.visible`)。SC-02 把进出城转移上移到 GameFlow(出征
   `on_depart` 出城 / `wave_boundary_settled[_return_pending]` 返城),`TownView` 退为纯视图——**单一发起点回到
   GameFlow,= ARCHITECTURE §6"屏可见性双发起点"债同步关闭**(落码后本条转✅)。GameOver 态仍无(团灭=回退刷怪,有意)。
   注:城镇四子板块(工匠/小队/酒馆/出征)为视图内 overlay,**不进 M2 态**,故未引入新 Flow 态;若日后屏数膨胀需
   ScreenManager / 子板块容器,先转 /arch-guard(见 STATE-CHANGE-02 §5 条件触发)。
5. **AICombat "状态机"已退化为无状态** — 现实只剩 `select_target`;无 per-entity 战斗行为机(无硬直/格挡/吟唱/位移态)。未来技能带吟唱/前摇会需要引入实体级战斗 FSM(届时**先转 /arch-guard** 定 `StateMachine` 结构,再回本机定态)。**且 ARCHITECTURE §3.1 仍描述它为"轻量状态机:寻敌/接近/进射程/出手",与现实不符 = 文档债**,宜回写 ARCHITECTURE。
6. **两套"停"语义重叠** — M4.running=false(城镇暂停,停 tick)与 M1.RESTING(修整,清敌留 tick)是两种"暂停",机制不同。未来统一"暂停"概念时需理顺二者。
7. **`enraged` 是每场单向 latch,无显式战斗阶段机** — 正确但无法表达多段狂暴 / 阶段 Boss。若要分阶段 Boss 需把它升级为"战斗阶段机"(战斗内 sub-FSM)。
8. **【已裁决·2026-06-20·City geometry】城镇窗口几何 = 复用 M3.EXPANDED,不新增几何态。** 触发:
   UX-CHANGE-04(按参考图重设计城镇枢纽 + 五子板块)§6① 问"城镇是否需放大工作窗"。核查:M2.TOWN
   **当前已渲染在 M3.EXPANDED 贴底全宽窗**(`enter_game_geometry()`→EXPANDED;`main_area.visible` 仅
   EXPANDED 为真,TownView/CombatView 同挂 `MainArea`);用户参考图为宽幅 ~3.2:1,**正是 800×250 贴底窗画幅**。
   → **裁决:城镇沿用 EXPANDED,M3 仍三态**(EXPANDED/COLLAPSED/MENU);若 UI 轮实测高度不足 = 调
   `EXPANDED_HEIGHT` 占位值(Art Spec 调参,非状态)。**M2↔M3 正交关系不变**(§5#7 维持)。
   **conditional-future(未触发,记此免遗忘)**:若 UI·juice 轮实证 250px 装不下最满板(如小队)且要城镇
   专属更大窗 → 那时才 (a) **先转 `/arch-guard`** 定 `MainArea` 舞台尺寸随 flow 变(现为固定 800×250 共享舞台)
   的结构,(b) 再回本机给 M3 加第 4 态 `TOWN`(仿 MENU:purpose-named、GameFlow 命令、1:1 锁定 M2.TOWN、
   无收起出口)。**本期不做**(无此需求证据;守硬 NO 不提前抽象)。

---
> **下一棒(可选)**:本文档仅"补档"——已把现状状态机立为事实源,未做重构。若要动其中任何一项
> (优先级最高 = §6.4 把 M2 游戏流程抽成显式机、§6.3 给 RESTING 补出口),开
> `/state-machine-master <slug>` 进模式 B 产出 `harness/state/STATE-CHANGE-NN-*.md` 交 Planner;
> 若涉及新模块/数据结构(如 §6.5 引入 `StateMachine` 节点类),先转 `/arch-guard`。

---
artifact: STATE-CHANGE
feature: 09-title-main-menu
role: State Machine Master
status: draft
updated: 2026-06-20
inputs: [STATE-MACHINES.md, UX-MAP.md, harness/ux/UX-CHANGE-01-title-main-menu.md, ARCHITECTURE.md, harness/features/09-title-main-menu/HANDOFF.md, BACKLOG.md, src/core/game_controller.gd, src/shell/floating_shell.gd, src/combat/combat_view.gd, src/combat/town_view.gd, src/core/combat/progression_controller.gd]
next: Arch Guard（结构确认）→ 回 State Machine Master 钉死 → Planner
---

# STATE-CHANGE-01 · 流程前门 + 系统枢纽(Boot→Title→Game,Menu 可从游戏调回)

> 把 UX-CHANGE-01 的屏图实现成**显式流程 FSM**,并清偿 STATE-MACHINES §6.4(M2 无显式机)。
> 本文只定**动态行为**(状态/事件/转移/守卫/进出动作);**结构归宿**(机住哪、三屏怎么挂、
> 谁命令几何)留 §5 标给 **arch-guard** 先定,我给了右尺寸推荐。

## 1. 触发 / Trigger

UX-CHANGE-01 给"启动即开打"的悬浮窗补前门:启动落**居中主菜单窗(MENU 几何)**,选完
收缩成贴底条进游戏;游戏中右上 `[☰]` 随时调回主菜单(唯一系统枢纽,挂 继续/新游戏/设置/退出)。
这要求把现状的**隐式 M2 游戏流程机**(`town_root.visible` + `arena.running` + 手动 show/hide
三布尔耦合)升成**显式流程 FSM**,并给 M3 悬浮窗几何机加一个 `MENU` 态。是 STATE-MACHINES
§6.4 列为"首要候选重构"的那台机。

## 2. 现状诊断 / Diagnosis(根因)

根因 = **缺"游戏流程前门 + 系统枢纽"这一整层状态;现有 M2 是隐式布尔,装不下 Title/Menu/确认。**

- **M2 无 enum 载体**(STATE-MACHINES §3「M2」):合法态 `{Boot, Combat, Town}` 靠
  `TownView._town_root.visible` + `CombatArena.running` + `Game.pause_run/resume_run` 三处耦合
  隐式表达。要再插 `Title` / `Menu(系统枢纽)` / `覆盖确认` / `退出确认` 四个态,布尔组合会爆炸
  (§6.4 预言的"布尔组合爆炸"正是此处)。
- **开打动作焊死在视图加载**:`CombatView._ready` 无条件 `Game.begin_run(stages)`(UX-CHANGE §2),
  玩家无从"先看菜单、先不打"。`begin_run` 触发点必须从视图 `_ready` 上移到**流程机的 Title→Game 转移**。
- **M3 几何机只有两态**:`floating_shell._state ∈ {EXPANDED, COLLAPSED}`,启动直接
  `_snap_window(_expanded_rect())` 贴底,**无 `MENU`(居中较大窗)几何**。
- **无"来源态记忆"**:`[☰]` 从 Explore 还是 Town 调出 Menu、"继续"该回哪,现状无任何寄存器。
- **`new_game` 不存在**:覆盖单档(`user://savegame.json`)+ `player_state.reset()` + `begin_run(0,0)`
  这条破坏性路径无人承载。

即:不是"缺一个菜单画面",是**缺流程层的状态**。这是状态机的活,不是单纯加 UI。

## 3. 目标形态 / Target machines(delta vs STATE-MACHINES §3)

### 3.1 M2 升级为显式流程机 `GameFlow`(本次主交付)

状态(建议 `enum Flow { BOOT, TITLE, EXPLORE, TOWN, MENU_OVERLAY }`):

| 态 | 含义 | M4.running | 几何(M3)| 内容屏 |
|----|------|-----------|----------|--------|
| `BOOT` | 装配/载档判定,瞬态 | false | (未定) | — |
| `TITLE` | 启动落点 = 主菜单(继续/新游戏/设置/退出) | **false**(还没 begin_run) | `MENU` | 主菜单 / 设置 / 覆盖确认 / 退出确认 |
| `EXPLORE` | 挂机战斗(默认玩) | **true** | `EXPANDED`(可 COLLAPSED) | 探索/战斗 + 背包面板 |
| `TOWN` | 城镇改装(暂停挂机) | **false** | `EXPANDED`(可 COLLAPSED) | 城镇 |
| `MENU_OVERLAY` | 游戏中经 `[☰]` 调回的系统枢纽,**记来源态** | **不变**(沿用来源态的值,见守卫) | `MENU` | 同 TITLE 的四屏 |

> **TITLE vs MENU_OVERLAY 的区别**:同一组屏,但 TITLE 是"启动/无来源"、MENU_OVERLAY 是"从
> EXPLORE/TOWN 调出、带 `return_to` 来源寄存器、`继续`=回来源"。两态共用屏内子结构(下 §3.2),
> 仅"继续/新游戏后去哪"和"是否暂停 sim"不同。可实现为一个态 + `return_to ∈ {NONE, EXPLORE, TOWN}`
> 子寄存器(NONE = 从 Title 启动);本表为清晰拆两态,落地由 arch-guard/Planner 选单态+寄存器或双态。

**子寄存器**:`menu_return_to ∈ {NONE, EXPLORE, TOWN}`(仅 MENU_OVERLAY 内有意义,记从哪调出)。

**转移表**(事件 = 玩家点击 / 启动 / OS):

| from | 事件 | 守卫 | to | 进出动作 |
|------|------|------|----|----------|
| (启动) | `boot_done` | — | **TITLE** | `_boot`(载档/registry/算续战游标)**只载不打**;按 `save_exists` 定主菜单默认态;命令 M3→`MENU` 几何 |
| TITLE | `continue` | `save_exists` | **EXPLORE** | 按续战游标 `begin_run`、M3→`EXPANDED`(收缩过渡)、`running=true` |
| TITLE | `new_game` | `not save_exists` | **EXPLORE** | `new_game`:清档 + `player_state.reset()` + `begin_run(0,0)`;M3→`EXPANDED`;`running=true` |
| TITLE | `new_game` | `save_exists` | TITLE(覆盖确认子屏) | 弹〔覆盖存档确认〕,不立即执行 |
| TITLE(覆盖确认) | `confirm` | — | **EXPLORE** | 同上 `new_game` 全流程 |
| TITLE(覆盖确认) | `cancel`/`Esc` | — | TITLE | 关确认,回主菜单 |
| TITLE | `open_settings` | — | TITLE(设置子屏) | 显设置屏 |
| TITLE(设置) | `back`/`Esc` | — | TITLE | 回主菜单 |
| TITLE | `quit` | — | TITLE(退出确认子屏) | 弹〔退出确认〕 |
| TITLE(退出确认) | `confirm` | — | (进程退出) | **autosave → quit** |
| TITLE(退出确认) | `cancel`/`Esc` | — | TITLE | 关确认 |
| EXPLORE | `enter_town` | — | **TOWN** | `pause_run()`:`_sync_party_equipment` 写回 + `running=false`;显城镇 |
| TOWN | `leave_town` | — | **EXPLORE** | `resume_run()`:据 Character 重快照 Entity(夹 hp,不回血)+ `running=true` |
| EXPLORE / TOWN | `open_menu`(`[☰]`) | — | **MENU_OVERLAY** | `menu_return_to = 当前态`;M3→`MENU`(放大过渡);**不动 `running`**(守支柱 1) |
| MENU_OVERLAY | `continue` | — | **回 `menu_return_to`** | M3→`EXPANDED`(收缩过渡);`running` 维持来源态的值(EXPLORE=true / TOWN=false);`menu_return_to=NONE` |
| MENU_OVERLAY | `open_settings` | — | MENU_OVERLAY(设置子屏) | 同 TITLE 设置 |
| MENU_OVERLAY | `new_game` | `save_exists` | (覆盖确认) | 同 TITLE 覆盖路径(confirm 后回 EXPLORE 新局) |
| MENU_OVERLAY | `quit` | — | (退出确认) | 同 TITLE 退出路径 |

### 3.2 屏内子状态(MENU 内容,TITLE/MENU_OVERLAY 共用)

```
主菜单 Main
  ├─ default·有存档   (继续=主操作 / 新游戏 / 设置 / 退出)
  ├─ default·无存档   (继续 disabled|隐藏 / 新游戏=主 / 设置 / 退出)
  ├─ 设置 Settings        ──Esc/返回──> 主菜单
  ├─〔覆盖存档确认〕      ──Esc/取消──> 主菜单 ; 确定──> 执行 new_game
  └─〔退出确认〕          ──Esc/取消──> 主菜单 ; 确定──> autosave→quit
```
这是一台**小子机**(嵌在 GameFlow 的 TITLE/MENU_OVERLAY 内),状态 = 主菜单 / 设置 /
覆盖确认 / 退出确认;唯一退法统一为 `Esc 退一级`(补 UX-MAP §6 债 #3)。

### 3.3 M3 悬浮窗几何机加 `MENU` 态(delta vs STATE-MACHINES §3「M3」)

状态 `enum State { EXPANDED, COLLAPSED, MENU }`(MENU = 居中较大窗,~560×400 由 Art Spec 定)。

| from | 事件 | 守卫 | to | 动作 |
|------|------|------|----|------|
| (启动) | `boot_done` | — | **MENU** | 几何跳变到 `_menu_rect`(居中) |
| MENU | `enter_game`(GameFlow 命令) | — | EXPANDED | 全透明瞬间跳变到 `_expanded_rect`(**复用既有退路,勿逐帧缓动**) |
| EXPANDED | `open_menu`(GameFlow 命令) | flow∈{EXPLORE,TOWN} | MENU | 跳变到 `_menu_rect` |
| EXPANDED | toggle(F1/收起/handle) | flow∈{EXPLORE,TOWN} | COLLAPSED | (原样)淡出→`_collapsed_rect`→降帧 15 |
| COLLAPSED | toggle(F1/handle) | — | EXPANDED | (原样)→`_expanded_rect`→60fps |
| (任意) | F2 | — | (态不变) | `_toggle_always_on_top`(原样,正交) |

> ⚠ **正交性收窄**:原 M3 与游戏逻辑**全正交**(不变量 #7)。加 `MENU` 后,**`MENU` 几何 ↔ TITLE/
> MENU_OVERLAY 内容是 1:1 锁定**(MENU 几何只在主菜单态出现),由 GameFlow 进出动作**命令** M3 切换;
> 而 `{EXPANDED,COLLAPSED}` 仍与 `{EXPLORE,TOWN}` 正交(游戏中可随意收起)。即:F1 收起只在
> EXPLORE/TOWN 可用,主菜单态下不可收起(MENU 态无 toggle 出口)。不变量 #7 需改写为"**部分正交**"。

## 4. 调整策略 / Strategy(依赖序,策略级,不写逐行代码)

1. **拆 `_boot` 与 `begin_run`**(所有屏的前置):`_boot` 只载档/registry/判 `save_exists`,**不 `begin_run`**;
   摘除 `CombatView._ready` 的无条件开打。`begin_run` 改由 GameFlow 的 `TITLE→EXPLORE` 转移触发。
2. **立 GameFlow 显式态 + `MENU` 几何**:启动落 `TITLE`(M3→`MENU` 几何);按 `save_exists` 切主菜单默认态。
   *(M1/M3/M4 转移表不变,只是 begin_run/running 的触发点上移到 GameFlow 的进出动作。)*
3. **绑进游戏过渡**:`continue` / `new_game`(有档先过覆盖确认)→ `begin_run` + M3 收缩 + `running=true`。
4. **加屏内子机**:主菜单 / 设置 / 覆盖确认 / 退出确认;Esc 统一退一级;退出确认→autosave→quit。
5. **加 `[☰]` 入口 + `menu_return_to`**:EXPLORE/TOWN 右上 `[☰]`→`MENU_OVERLAY`(记来源、不动 running);
   `继续`=回来源态 + M3 收缩。
6. **改写不变量**:STATE-MACHINES §5 #1(M2 现有显式态了)、#7(M3 部分正交)、新增"仅 TOWN 暂停
   挂机;TITLE/MENU_OVERLAY/COLLAPSED 不暂停"(对齐 UX-CHANGE 新不变量、守支柱 1)。

转移在每一步后行为自洽:先拆 boot(游戏仍能从 Title 手动开打)→ 再叠菜单子屏 → 再叠 `[☰]` 回流,
任一步落地后都不产生非法态。

## 5. 影响面与迁移 / Blast radius(⚠ 含必须先定的结构)

**触及**:`game_controller.gd`(boot/begin_run/new_game/flow 态)、`floating_shell.gd`(MENU 几何 +
`_menu_rect`)、`combat_view.gd`(摘自动开打 + `[☰]`)、`town_view.gd`(`[☰]` + 进出城接 flow)、
`SaveSystem`(`new_game` 清档)、UX-MAP §2/§4、ARCHITECTURE §3.1 文档债顺带。

**⚠ 必须先转 /arch-guard 定的结构(本次硬交接,3 个决策)**:
1. **GameFlow 流程机的归宿**:enum + 集中转移派发**住哪**?——我的推荐 = **进 `game_controller.gd`**
   (它已是 boot 入口 + 单局编排座,flow 态天然属它;与 M1 住 ProgressionController、M3 住 floating_shell
   的"enum 住所属模块"风格一致)。**不建议**本期新起 `GameFlow`/`ScreenManager` autoload —— 当前仅
   1 个 MENU 窗 + 4 个简单子屏,够不上独立屏管理器,是过度工程。
2. **三屏(主菜单/设置/确认)的挂载范式**:沿用现有 **show/hide 面板**(同城镇/背包面板,纯 `visible`
   切换)即可?还是要引入屏生命周期/`StateMachine` 基类?——我的推荐 = **沿用 show/hide**,把
   "统一 FSM 范式 / ScreenManager"(STATE-MACHINES §6.1)留作**屏数量长大后**的独立重构,别在本期捆绑。
3. **谁命令几何**:GameFlow 进出动作**调用** `floating_shell`(MENU↔EXPANDED)——这是表现层依赖方向问题,
   需 arch-guard 确认 `game_controller`→`floating_shell` 的调用合规(或反向由 shell 监听 flow signal)。

**向后兼容**:存档格式不动(`new_game` 只删文件);M1/M4 转移表零改动(仅触发点搬家);续战游标判别
(ARCHITECTURE 不变量 #9)不变。

## 6. 风险与被否选项 / Risks & rejected alternatives

- **风险:MENU↔strip 几何反复切换抖动**(Windows 改窗几何已知坑)。缓解 = 复用 floating_shell 既有
  "全透明瞬间跳变几何"退路,菜单进出**不逐帧缓动**(UX-CHANGE §6 同款)。
- **风险:MENU_OVERLAY 不暂停 sim,久留回来已推进/团灭数轮**。判定可接受(支柱 1 后台推进);"继续"
  回来靠既有战斗日志读懂。
- **被否:把 GameFlow 做成新 `ScreenManager` autoload + StateMachine 基类**。理由:本期屏少,会过度工程;
  §6.1 范式统一留作屏长大后的独立重构,不阻塞本前门。(若 arch-guard 评估认为现在就该立基类 → 由它拍。)
- **被否:MENU 单纯做成 M3 的几何态、不升 M2 为显式机**。理由:Title/确认/设置是**内容流程态**不是窗口
  几何,硬塞 M3 会把布尔耦合搬进 floating_shell,§6.4 债不减反增。
- **被否:Menu 暂停 sim**。与"后台持续推进"支柱冲突,否(沿用 UX-CHANGE 决策)。
- **被否:TITLE 与 MENU_OVERLAY 各做一台独立机**。二者共用四屏,仅 `return_to`/是否暂停不同,
  合为一台 + 寄存器更省;本文拆两态仅为转移表可读,落地可合。

## 7. 交接 / Handoff

- **下一棒 = /arch-guard**(本次硬交接):定 §5 的 3 个结构决策(GameFlow 归宿 / 三屏挂载范式 /
  flow→几何 命令方向)。我已给右尺寸推荐(最小:enum 进 game_controller、屏沿用 show/hide、
  不上 ScreenManager),arch-guard 确认或推翻后产 `harness/arch/REFACTOR-NN-*.md`。
- **结构定了 → 回 State Machine Master**:把 §3 转移表对齐到落定结构(预期零改动,仅确认归宿),
  或我直接收尾后转 Planner。
- **再 = /role-planner 09-title-main-menu**:把本 STATE-CHANGE §4 策略 + UX-CHANGE-01 落成有序
  PLAN(① 拆 boot/begin_run ② MENU 几何+过渡 ③ 主菜单/设置/两确认子屏 ④ `[☰]`+`menu_return_to`
  ⑤ Esc 统一返回)。
- **/role-art-spec**:Title/主菜单/设置三屏 + `[☰]` 图标 + strip↔MENU 过渡(并入全局 UI·juice 一轮)。
- **顺带文档债**:ARCHITECTURE §3.1 仍把 AICombat 写成"轻量状态机",与现实不符(STATE-MACHINES §6.5),
  本次不修但提醒 arch-guard 回写。

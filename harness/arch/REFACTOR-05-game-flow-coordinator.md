---
artifact: REFACTOR
feature: 09-title-main-menu
role: Arch Guard
status: draft
updated: 2026-06-20
inputs: [ARCHITECTURE.md, project-context.md, harness/state/STATE-CHANGE-01-title-main-menu.md, harness/ux/UX-CHANGE-01-title-main-menu.md, STATE-MACHINES.md, src/core/game_controller.gd, src/shell/floating_shell.gd, scenes/shell/floating_shell.tscn, src/combat/combat_view.gd, src/combat/town_view.gd, src/core/systems/save_system.gd]
next: Planner
---

# REFACTOR-05 · 流程协调器归宿(GameFlow 落表现层,守依赖方向)

> 回应 STATE-CHANGE-01 §5 抛给 arch-guard 的三个结构决策。本文只定**静态结构**(归宿 / 边界 /
> 依赖方向 / 接缝),**动态转移表**是 STATE-MACHINES / STATE-CHANGE-01 的事,不在此重复。

## 1. 触发 / Trigger

09-title-main-menu 要把隐式 M2 游戏流程升成显式 `GameFlow` FSM(Boot→Title→Game{Explore↔Town}
+MENU_OVERLAY)+ 给悬浮窗加 `MENU` 几何态。State Machine Master 在 STATE-CHANGE-01 §5 停转 arch-guard,
要我先定三件结构事:① 流程机归宿;② 三屏挂载范式;③ flow→几何 命令方向是否合规。

## 2. 现状诊断 / Diagnosis(根因 = 依赖方向)

**根因:游戏流程要同时路由「屏切换 + 窗口几何」(表现层关切)与「sim 开关 / 建队」(逻辑层关切);
现状这两件本就由表现层发起,而非 core。把流程机放错层会撞 ARCHITECTURE §3.3 的依赖红线。**

代码实证(grounded):
- **M2 的转移现状就活在表现层**,GameController 只供机制:
  - `combat_view.gd:98-99` —— `if not stages.is_empty(): _gc.begin_run(stages)`,**开打动作焊死在视图 `_ready`**;`stages: Array[StageConfig]` 由 `floating_shell.tscn:50` 挂在 CombatView 上。
  - `town_view.gd:40-59` —— `_enter_town` 调 `_gc.pause_run()` + `_town_root.visible=true` + 反查兄弟 `get_parent().get_node("CombatView")` 隐之;`_leave_town` 反之。
  - `game_controller.gd` —— `begin_run/pause_run/resume_run` 都是**机制方法**,不决定"何时切、切到哪屏"。
- **屏 = MainArea 下的兄弟 Control,靠 `.visible` 切**(`floating_shell.tscn`:`MainArea/{CombatView,TownView}`);背包面板 = CombatView 内 `_panel.visible`。**全项目无 ScreenManager、无 StateMachine 基类**——show/hide 兄弟是既成范式。
- **窗口几何归 `floating_shell.gd`**(presentation 根),`enum State{EXPANDED,COLLAPSED}` + 私有 `_set_state`;无对外几何 API、无 `MENU` 态。
- **依赖红线**(ARCHITECTURE §3.3):表现层→逻辑层(只读 + 监听 signal);**逻辑层不依赖表现层**。`GameController` 是 autoload core 层,**当前不碰任何表现节点**。

⇒ 若按"流程 enum 进 `game_controller`"做,GameController 就得**反向调用** `floating_shell`(改 MENU 几何)
和菜单屏(show/hide)——**逆依赖、破 §3.3**;退路是全程发信号让表现层监听,但那把"当前在哪个屏"
这种纯表现关切塞进了 core autoload,味道同样不对。**这不是"装不下",是"装错层"。**

## 3. 目标形态 / Target shape(delta vs ARCHITECTURE §3)

### 3.1 新增 1 个**表现层** shell 级协调节点 `GameFlow`(本次结构核心)

- **层归属**:表现层(挂在 `FloatingShell` 场景内),**不是 autoload、不是 core**。
- **持有**:`enum Flow { BOOT, TITLE, EXPLORE, TOWN, MENU_OVERLAY }` + 子寄存器 `menu_return_to`;
  并**宿主四个菜单屏**(主菜单 / 设置 / 覆盖确认 / 退出确认)作为其子节点。
- **依赖方向(全合法)**:
  - **向下调逻辑**:`Game.begin_run / new_game / pause_run / resume_run`(表现→逻辑,**与现状视图同款**)。
  - **横向命令几何**:调 `floating_shell` 的**新公开几何 API**(presentation→presentation,层内)。
  - **管自己的菜单屏可见性**:`.visible` 切(同既成 show/hide 范式)。
- **绝不**:core(`Game`/`PlayerState`)**反向依赖** `GameFlow`;`GameFlow` 不碰数值/存档内部(只调 `Game` 机制方法)。

> 这是"把已经散在 CombatView/TownView 里的流程决策**收拢成一个显式表现层协调器**",不是引入新框架。
> **不新增 autoload、不引入 ScreenManager、不抽 StateMachine 基类**(守 project-context hard-NO
> "不为还没影的后期系统提前抽象";4 个简单屏够不上屏管理器)。

### 3.2 `floating_shell.gd` 开放几何接缝 + `MENU` 态(delta vs §3.2 表现层)

- `enum State` 加 `MENU`;加 `_menu_rect()`(居中 ~560×400,具体尺寸 Art Spec 定)。
- **对外公开几何意图 API**(供 `GameFlow` 横向调用),复用既有"全透明瞬间跳变几何"退路(`_set_state`
  那套 Tween),**不逐帧缓动**(守 PLAN R1 Windows 改窗几何抖动退路)。
- `{EXPANDED,COLLAPSED}` 的 F1 收起/展开维持原样,但**仅在 flow∈{EXPLORE,TOWN} 时可用**
  (MENU 态无收起出口)——见 §3.4 不变量改写。

### 3.3 `game_controller.gd` 只加机制接缝(delta vs §3.2 GameController)

- 加 `has_save: bool` —— `_boot` 里 `load_file` 后落定(供菜单"继续 vs 新游戏"默认态守卫读)。
- 加 `new_game()` —— `player_state.reset()` + `begin_run(stages,0,0)` + `_autosave()`(**覆盖**单档,
  无需 SaveSystem 加 `delete`;落盘即清旧档)。
- `begin_run/pause_run/resume_run` **签名与逻辑不变**,仅**触发点从 CombatView._ready 上移**到 `GameFlow` 的
  TITLE→EXPLORE 转移。
- **`stages: Array[StageConfig]` 配置归属从 CombatView 迁到 `GameFlow`**(谁调 `begin_run` 谁持关卡表;
  `floating_shell.tscn` 里把该数组挪到 GameFlow 节点)。

### 3.4 不变量改写(delta vs ARCHITECTURE §4 / 兼 STATE-MACHINES §5)

- **新增**:`GameFlow` 是**表现层**协调器;**core 永不依赖它**,它只经"向下调 `Game` 机制方法 + 横向调
  `floating_shell` 几何 API"驱动,所有跨层仍守 §3.3 + 信号过去式(§4#5)。
- **新增**:**仅 TOWN 暂停挂机**(`pause_run`,`running=false`);TITLE/MENU_OVERLAY/COLLAPSED **不暂停**
  (`running` 不变,守支柱 1 后台推进)。
- **改写**:原"窗口几何与游戏逻辑全正交"收窄为**部分正交**——`MENU` 几何 ↔ 主菜单内容 1:1 锁定
  (由 `GameFlow` 命令);`{EXPANDED,COLLAPSED}` 仍与 `{EXPLORE,TOWN}` 正交。

## 4. 调整策略 / Strategy(依赖序,结构级,不写逐行代码)

1. **GameController 接缝先行**(纯加法,不破现状):加 `has_save` + `new_game()`;此步后旧流程仍能跑。
2. **floating_shell 开几何接缝**:加 `MENU` 态 + `_menu_rect` + 对外几何 API(EXPANDED↔MENU);旧 F1 行为不变。
3. **拆 CombatView 自动开打**:摘 `combat_view.gd:98-99` 的无条件 `begin_run`,`stages` 配置迁出。
   *(此步后启动不再自动开打——必须紧接第 4 步补上入口,否则空窗;Planner 排序需把 3、4 同批落地。)*
4. **引入 `GameFlow` 协调节点**:挂进 `FloatingShell` 场景,宿主四菜单屏,持 `enum Flow`+`menu_return_to`;
   启动落 TITLE(命令 floating_shell→MENU 几何);按 `Game.has_save` 切默认态。
5. **接线转移**:按 STATE-CHANGE-01 §3.1 转移表,把 continue/new_game/[☰]/设置/确认/Esc 钉到 `GameFlow`
   上(向下调 `Game`、横向调几何 API)。EXPLORE↔TOWN 的进出城**维持现有 TownView 逻辑**(见 §5 取舍),
   `GameFlow` 仅在 `[☰]` 时记 `menu_return_to`。

## 5. 影响面与迁移 / Blast radius & migration

- **`scenes/shell/floating_shell.tscn`**:加 `GameFlow` 节点(+ 四菜单屏子节点);`stages` 数组从 CombatView 挪到 GameFlow。
- **`src/shell/floating_shell.gd`**:+`MENU` 态 +`_menu_rect` + 公开几何 API(纯加法,不动 COLLAPSED 路径)。
- **`src/core/game_controller.gd`**:+`has_save` +`new_game()`(纯加法;begin_run/pause/resume 不改)。
- **`src/combat/combat_view.gd`**:摘自动 `begin_run` + 移除 `stages` 持有;加右上 `[☰]`(排布交 Art Spec)。
- **`src/combat/town_view.gd`**:加 `[☰]`;进出城逻辑**基本不动**(见下取舍)。
- **`harness/STATE-MACHINES.md` / `UX-MAP.md`**:落地后把 🔜 转现状(SMM / UX 各自回写)。
- **存档**:格式**零改动**(`new_game` 走覆盖,不加字段、不需 `SaveSystem.delete`)。M1 进度机 / M4 运行开关 **转移表零改动**(仅 begin_run/running 触发点搬家)。续战游标判别(§4#9)不受影响。
- **测试**:`GameFlow` 是表现层节点,**靠手动 Play 验**(同 floating_shell/视图,守 project-context §1 "UI 靠肉眼");纯逻辑 `new_game`/`has_save` 可补 gdUnit4(走 `_boot(load_save=false)` 注入路径)。

**取舍(限爆炸半径)**:本期让 `GameFlow` 只统管 **MENU 几何 ↔ 游戏** 这一层;**EXPLORE↔TOWN 的进出城
维持 TownView 现有 `pause_run/resume_run`+兄弟 `.visible` 实现**(已合法且能用),不强行收编进协调器。
代价 = "屏可见性"暂有两个发起点(协调器管菜单、TownView 管城镇),记入 §6 债,留屏长大后再统一。

## 6. 风险与被否选项 / Risks & rejected alternatives

- **被否:流程 enum 放进 `game_controller`(State Machine Master 的初始推荐)。** 否因:GameController 是
  core autoload,流程要路由屏 + 窗口几何(表现层),放这儿会**逆依赖调用表现层、破 §3.3**;退而全程发信号
  又把"在哪个屏"这种表现关切塞进 core。**结论:归宿改表现层协调器**(SMM 的"不上 ScreenManager/基类"
  我保留;仅"住哪"这一点修正)。
- **被否:引入 `ScreenManager` + `StateMachine` 基类 + 导航栈。** 否因:project-context hard-NO"不为还没影
  的后期系统提前抽象";4 个互斥简单屏用既成 show/hide 即可。**统一 FSM 范式(STATE-MACHINES §6.1)留作
  屏数量长大后的独立重构**,不阻塞本前门。
- **被否:把流程机塞进 `floating_shell.gd`。** 否因:floating_shell 是项目里最干净的几何 FSM(纯窗口、
  正交,STATE-MACHINES §5#7);掺入 begin_run/菜单屏路由会污染它、加深耦合。故另起协调节点,floating_shell
  只**开几何 API** 被调。
- **风险:第 3 步摘掉自动开打后、第 4 步入口未就位 → 空窗。** 缓解:Planner 把步 3、4 同批落地、单测/手验串起。
- **风险:菜单不暂停 sim,久留回来已推进/团灭数轮。** 判定可接受(支柱 1 后台推进;沿用 UX-CHANGE-01 决策)。
- **债:屏可见性双发起点**(见 §5 取舍)——记入 ARCHITECTURE §6,屏长大后统一。

## 7. 交接 Planner / Handoff

- **下一棒 = `/role-planner 09-title-main-menu`**,喂本文 `harness/arch/REFACTOR-05-game-flow-coordinator.md`
  + `harness/state/STATE-CHANGE-01-title-main-menu.md` + `harness/ux/UX-CHANGE-01-title-main-menu.md`,落成有序 PLAN。
  Planner 把 §4 五步拆成文件级可验证步骤(尤其步 3+4 同批,避空窗);转移细节照 STATE-CHANGE-01 §3。
- **结构已定,State Machine Master 无需再回**(转移表不因归宿改变;落地后把 STATE-MACHINES 🔜 转现状即可)。
- **Art Spec**:MENU 窗尺寸 / 三屏视觉 / `[☰]` 图标 / strip↔MENU 过渡 —— 并入全局 UI·juice 一轮。
- **顺带文档债(本文已修)**:ARCHITECTURE §3.1 旧称 `AICombatComponent` 为"轻量状态机",与现实(已退化为
  无状态 `select_target`,STATE-MACHINES §6.5)不符 —— 本次 drive-by 在 §3.1 标注现状。

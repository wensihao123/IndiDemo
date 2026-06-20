---
artifact: UX-CHANGE
feature: cross-cutting (落地挂 09-title-main-menu)
role: UX Design
status: accepted
updated: 2026-06-20
inputs: [UX-MAP.md, project-context.md, BACKLOG.md, harness/state/STATE-CHANGE-01-title-main-menu.md, harness/arch/REFACTOR-05-game-flow-coordinator.md, STATE-MACHINES.md, src/shell/floating_shell.gd, src/core/game_controller.gd, src/combat/combat_view.gd, src/combat/town_view.gd, scenes/shell/floating_shell.tscn]
next: Planner
---

# UX-CHANGE-01 · Title / 主菜单 / 设置(landing + 系统枢纽)

## 0. 对齐说明(2026-06-20 · 下游 SMM + Arch Guard 回填后转 accepted)
下游已消化本方案并与之**一致、无结构冲突**:State Machine Master 把本屏图落成显式 `GameFlow` FSM
(`STATE-CHANGE-01`),Arch Guard 把流程机归宿定为**表现层 `GameFlow` 协调节点**(`REFACTOR-05`,
非进 core `game_controller`),并采纳本方案 §6"探索↔城镇暂不升级为统一模式"的取舍。结构已定,
下一棒直接 Planner。三处**玩家可见的交互细化**(本次回写,已同步 UX-MAP):
- **主菜单 = 同一屏的两个流程语境**:`TITLE`(启动落点,无来源)/ `MENU_OVERLAY`(游戏中经 `[☰]` 调回,
  带 `menu_return_to` 来源寄存器)。玩家可见差异仅两点:「继续」去哪(TITLE→续战/新局;OVERLAY→回来源态),
  以及——两者都**不暂停 sim**。**设置 / 新游戏 / 退出在两个语境均可达**(从游戏中也能开新档,经覆盖确认)。
- **部分正交(收起规则)**:`收起`(F1 / handle)**仅在 EXPLORE/TOWN 可用**;**主菜单态(MENU 几何)无收起出口**——
  离开主菜单只能走 继续 / 新游戏 / 退出。原"窗口几何 × 游戏逻辑全正交"收窄为**部分正交**(MENU 几何 ↔ 主菜单内容 1:1 锁定)。
- **Esc 约定补全**:子层(设置 / 覆盖确认 / 退出确认)`Esc` 退一级;**顶层 `MENU_OVERLAY` 的 `Esc` = 继续**
  (回来源,符合"退一级"心智);顶层 `TITLE` 为根屏、**无 Esc 出口**。← 交 SMM 钉进转移表(当前 STATE-CHANGE-01 §3.1 只定了子层 Esc)。

## 1. 触发 / Trigger
v1 功能切片全部完成、即将进"全局 UI·juice 一轮"(BACKLOG Next①),但游戏**启动即开打**,
从无 Title / 主菜单 / 设置 / 退出入口(UX-MAP §6 债 #1/#2/#4)。用户决定从 landing page + 主菜单
入手,把这三块结构性洞一次锚定。**两项关键决策(用户 2026-06-20 拍板)**:
- 主菜单 = **启动时一个较大的居中独立窗口**,玩家选完后窗口**收缩成贴底 800×250 条**进游戏。
- 主菜单是**可随时回的全局 hub**:游戏中右上常驻 `[☰]` 入口能调回主菜单;**设置/退出只此一处**。

## 2. 现状诊断 / Diagnosis
根因:**这个游戏从来只有一种"窗口几何 + 一种内容入口"——启动 = 贴底条 + 立刻开打,没有"系统/前门"这一层。**
- `floating_shell.gd::_ready` 直接 `_snap_window(_expanded_rect())` 把窗贴底,几何 FSM 只有
  `EXPANDED`(贴底条)/`COLLAPSED`(图标)两态,**没有"菜单"几何**。
- `game_controller.gd::_ready` `auto_boot` 即 `_boot`(载存档/registry),而 `combat_view.gd::_ready`
  **无条件 `_gc.begin_run(stages)`**——开打动作焊死在视图加载里,玩家无从"先不打、先看菜单"。
- 退出唯一路径 = OS 关窗(`_notification(WM_CLOSE_REQUEST)` autosave);设置/键位硬编码不可改。
即:**缺的不是"一个菜单画面",而是"游戏流程的前门 + 系统枢纽"这一整层概念**——所有系统级入口
(继续/新档/设置/退出)都无处可挂。

## 3. 目标形态 / Target flow(delta vs UX-MAP §2)

### 窗口几何 FSM(A 套)新增一态:`MENU`(较大居中独立窗)
```
[启动] ──> MENU(居中较大窗,建议 ~560×400;具体尺寸交 Art Spec)
MENU ──继续 / 新游戏──> 收缩过渡 ──> STRIP_EXPANDED(全宽贴底 800×250)
STRIP_EXPANDED / Town ──点右上[☰]──> 放大过渡 ──> MENU(记住来源态)
MENU ──继续──> 回到来源态(Explore 或 Town)
MENU ──退出──> 〔退出确认〕──> autosave ──> quit
(F2 置顶切换、STRIP_EXPANDED↔COLLAPSED 维持原样,与本态正交)
```

### 主区/窗口内容态(B 套)新增三屏:
```
主菜单 Title/Main-Menu(MENU 几何内)
  ├─[继续游戏]   (有存档时主操作;无存档时 disabled/隐藏)
  ├─[开始新游戏] (有存档时 → 〔覆盖存档确认〕→ 清档+reset+begin_run(0,0))
  ├─[设置] ──> 设置 Settings(子屏)
  └─[退出] ──> 〔退出确认〕
设置 Settings  ──Esc/返回──> 主菜单
〔覆盖确认 / 退出确认〕 ──Esc/取消──> 主菜单 ; ──确定──> 执行
```

### 新确立的不变量(写回 UX-MAP §4):
- **仅 Town(改装备)暂停挂机;Menu / Collapse 不暂停**(守支柱 1"后台持续推进")。Menu 只是放大的系统态,sim 照跑。
- **破坏性动作二次确认**:新游戏覆盖存档、退出,均需 confirm 态。
- **Esc 统一返回上一层**:设置/确认层 Esc 退一级;顶层主菜单"继续"= 回游戏。(补 §6 债 #3)

## 4. 调整策略 / Strategy(依赖序,策略级,不写逐行代码)
1. **拆"启动即开打"**:启动只做 `_boot`(载存档/registry + 判定有无存档),**不再自动 `begin_run`**;
   `combat_view.gd::_ready` 里的无条件开打摘除。这是所有后续屏的前置。
2. **加 `MENU` 几何态 + 主菜单屏**:启动落到 MENU 居中窗;按"有无存档"切默认态(继续主 / 仅新游戏)。
3. **绑定进游戏过渡**:`继续`=按续战游标 `begin_run` + 几何收缩贴底;`新游戏`=(有存档先过覆盖确认)清档+`reset`+`begin_run(0,0)`+收缩贴底。
4. **加两个 confirm 子态**:覆盖存档确认、退出确认;退出确认→autosave→quit。
5. **加设置子屏**:最简含 音量(占位)/ 键位显示(为债 #6 重映射留位)/ 关于;从主菜单进、Esc 回。
6. **游戏中常驻 `[☰]` 入口**(Explore/Town 右上):调出主菜单(记来源态,"继续"即回来源),使主菜单成为唯一系统枢纽。
7. **统一 back/cancel**:设置/确认层一律 Esc 退一级(确立约定,补债 #3)。

## 5. 影响面与迁移 / Blast radius
- **`floating_shell.gd`(几何 FSM)**:加 `MENU` 居中态 + `STRIP↔MENU` 过渡。⚠ 复用其既有"全透明瞬间跳变几何"退路
  (PLAN R1 已知坑:Windows 改窗几何会抖),**不要逐帧缓动窗口几何**。
- **`game_controller.gd`**:把 `auto_boot` 的"载入"与"开打"解耦——`_boot`(载) 保留在启动,`begin_run` 改由菜单驱动;
  新增 `new_game`(清 `user://savegame.json` 单档 + `player_state.reset()` + `begin_run(0,0)`)。
- **`combat_view.gd` / `town_view.gd`**:摘除 CombatView 自动 `begin_run`;右上加 `[☰]` 入口(与既有 收起/进城/推进 共处,排布交 Art Spec)。
- **存档**:单槽 `user://savegame.json`——"新游戏"对有档玩家是破坏性操作,必须确认。
- **STATE-MACHINES.md(待建)**:本图的几何 FSM(Boot→Menu→Game{StripExpanded↔Collapsed},Menu 可从 Game 调出并记来源)= **State Machine Master** 要落的流程 FSM;与 UX-MAP §2 互映。
- **Art Spec / 全局 UI·juice 一轮**:Title / 主菜单 / 设置三屏 + `[☰]` 图标 + strip↔centered 过渡 = 新增视觉面;
  **正好并入即将启动的那一轮**(本 UX-CHANGE 就是给那轮兜"有哪些屏/态"的底)。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **风险:strip↔centered 几何反复切换抖动**(Windows 改窗几何已知坑)。缓解:走 floating_shell 既有"全透明瞬间跳变几何"同款退路,菜单进出不逐帧缓动。
- **风险:菜单不暂停 sim → 久留后回来已推进/团灭过几轮**。判定可接受(支柱 1 后台推进);"继续"回来靠既有战斗日志读懂发生了什么。
- **风险:`[☰]` 挤占战斗 HUD 右上**(已有 收起/推进/狂暴横幅)。交 Art Spec 排布,UX 仅占位一个角标入口。
- **被否:菜单装在 strip 内(不放大窗)** —— 用户选独立窗口:开屏更分明、"主菜单=放大的系统态"心智更清晰。代价是要动几何 FSM,已接受。
- **被否:菜单暂停 sim** —— 与"后台持续推进"支柱冲突,否。
- **被否:Title 只启动出现一次、游戏中回不去** —— 债 #4 只解一半、设置/退出无处稳定挂,否(选了可随时回的 hub)。

## 7. 交接 / Handoff
- **下一棒 = Planner**:开 `/role-planner 09-title-main-menu`,喂本文 `harness/ux/UX-CHANGE-01-title-main-menu.md`
  落成 PLAN。重点:① `begin_run` 与 `_boot` 解耦 + 摘 CombatView 自动开打;② `MENU` 几何态 + 收缩/放大过渡;
  ③ 主菜单/设置两屏 + 两个 confirm 态;④ `[☰]` 入口 + 记来源态;⑤ Esc 统一返回约定。
- **State Machine Master**:据本 §3 落 `STATE-MACHINES.md` 流程 FSM(Boot→Menu→Game{StripExpanded↔Collapsed},Menu 可从 Game 调出并记来源),与 UX-MAP §2 保持一致。
- **Art Spec(/role-art-spec)**:Title / 主菜单 / 设置三屏 + `[☰]` 图标 + strip↔centered 过渡视觉,**并入全局 UI·juice 一轮**。
- **Game Designer(可选)**:首启引导 / "继续 vs 新游戏" 文案措辞。

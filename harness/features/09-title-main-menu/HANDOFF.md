# HANDOFF · 09-title-main-menu

> 每个功能的单一事实来源(管线状态 + 下一步)。每个 role 干完更新它。

## 一句话
给"启动即开打"的悬浮窗游戏补上前门 + 系统枢纽:启动落**居中主菜单窗**(继续/新游戏/设置/退出),
选完**收缩成贴底条**进游戏;游戏中右上 `[☰]` 可随时回主菜单。一并解 UX-MAP 债 #1/#2,部分解 #3/#4。

## 管线状态
- [x] **UX Design**(2026-06-20)— 产 `harness/ux/UX-CHANGE-01-title-main-menu.md`(交互调整方案);
  UX-MAP.md 已更新到目标形态(新增 MENU 几何态 + Title/设置/确认三屏,🔜 标记待落地)。
- [x] **State Machine Master**(2026-06-20)— 产 `harness/state/STATE-CHANGE-01-title-main-menu.md`
  (流程 FSM:M2 升显式 `GameFlow` Boot→Title→Game{Explore↔Town}+MENU_OVERLAY、M3 加 `MENU` 几何);
  STATE-MACHINES.md 已标 🔜 目标态。**撞结构 → 先转 /arch-guard**(见 STATE-CHANGE-01 §5 三决策)。
- [x] **Arch Guard**(2026-06-20)— 产 `harness/arch/REFACTOR-05-game-flow-coordinator.md`;ARCHITECTURE.md 已标 🔜 目标态。
  **三决策定案**:① 流程机归宿 = **表现层 `GameFlow` 协调节点**(修正 SMM 的"进 game_controller"——core 放它会逆依赖破 §3.3);
  ② 三屏 = **沿用 show/hide**(不上 ScreenManager/基类,守 hard-NO);③ flow→几何 = 协调器横向调 floating_shell 公开几何 API(层内合法)。
- [x] **Planner**(2026-06-20)— 产 `harness/features/09-title-main-menu/PLAN.md`;把三份事实源落成
  6 步文件级可验证 PLAN(7 决策含被否项)。**⚠ 步 3+4 同批**(摘自动开打 + 引入 GameFlow,避空窗)。
- [x] **Implementer**(2026-06-20)— 产 `harness/features/09-title-main-menu/CHANGES.md`(含 Wiring Contract)。
  落地步 1-5:GameController `has_save`/`new_game`/`quit_game`;floating_shell `MENU` 态 + 公开几何 API;
  新建 `src/shell/game_flow.gd`(流程机)挂进 .tscn;摘 CombatView 自动开打 + stages 迁 GameFlow;
  CombatView/TownView 加 `[☰]` + group 查找;TownView 加 `reset_to_combat()`。
  **验证**:`--check-only` 0 error;gdUnit4 **156/156 PASS 0 orphan**。**手动 Play 未做**(headless 不能验 GUI)
  → CHANGES §6 待验清单交 Engine Integrator / 人。1 处偏差(`reset_to_combat`,PLAN 已预留)见 CHANGES §4。
- [x] **Engine Integrator**(2026-06-20)— 产 `harness/features/09-title-main-menu/INTEGRATION-STEPS.md`(**accepted**)。
  自动闸全绿(`--headless --import` 0 error、3s 启动 `_ready` 链 0 报错、156/156 测);**人手动 Play 验收通过**
  (D1-D9 全链路无问题:启动落菜单、收缩进游戏、`[☰]` 不暂停 sim、覆盖/退出二次确认、Esc 退一级、几何无抖动)。
- [ ] **Art Spec** — Title/主菜单/设置三屏 + `[☰]` 图标 + strip↔centered 过渡视觉(并入全局 UI·juice 一轮)。
- [x] **Reviewer**(2026-06-20)— 产 `harness/features/09-title-main-menu/REVIEW.md`。读真实代码对照 PLAN D1-D7 +
  CHANGES W1-W7。**结论 APPROVE WITH NITS**:无 must-fix/should-fix;支柱 1 红线(菜单不暂停 sim)代码层确认守住
  (`open_menu`/`_resume_to_source` 不触 `arena.running`);D1-D9 全部对上。3 处 nit(`[☰]` 占位坐标 N1、
  `reset_to_combat` 三行重复 N2、启动首帧贴底闪 N3)均不阻塞,并入 Art Spec·juice 轮。

## 关键决策(用户 2026-06-20 拍板)
- 主菜单 = 启动时**居中较大独立窗**,选完**收缩成贴底 800×250 条**(动现有几何 FSM,已接受)。
- 主菜单 = **可随时回的全局 hub**,游戏中经 `[☰]` 调出;**设置/退出只此一处**。
- 暂停规则:**仅 Town 暂停挂机;Menu/Collapse 不暂停**(守支柱 1 后台推进)。
- 破坏性动作(新游戏覆盖单档 / 退出)**二次确认**;`Esc` 统一返回上一层。

## 下一步
**功能已落地、人手动 Play 验收通过(EI accepted)、代码评审通过(Reviewer APPROVE WITH NITS)、
事实源已回写(步 6 完成)。剩一件,非阻塞:**
- [x] **步 6 回写事实源(2026-06-20)**:`STATE-MACHINES.md`(M2 升显式 GameFlow、M3 加 MENU、§5#1/#7/#8、§6.4 闭合)、
  `UX-MAP.md`(主菜单/设置/[☰]/Esc/几何部分正交转现状,债 #1/#2/#4/#7 闭合,#3 余推广)、
  `ARCHITECTURE.md`(§3.2 GameController+GameFlow、§3.3 依赖方向、§6 两条遗留张力)的 🔜 全部转现状。
1. **视觉占位 → `/role-art-spec`**(并入全局 UI·juice 一轮):见 REVIEW N1-N3 / CHANGES W7 —— MENU 窗 560×400、
   四屏视觉/排布、`[☰]` 图标位置、strip↔MENU 过渡、启动首帧贴底闪。
- **视觉占位 → `/role-art-spec`**(可延后并入全局 UI·juice 一轮):MENU 窗尺寸(占位 560×400)/三屏视觉/`[☰]` 图标位置/
  strip↔MENU 过渡/启动首帧贴底闪——见 CHANGES Wiring W7 / INTEGRATION-STEPS Flags。
- **步 6 回写事实源(各 role)**:落地确认后 SMM/UX/Arch 把 `STATE-MACHINES.md`/`UX-MAP.md`/`ARCHITECTURE.md`
  的 🔜 转现状(GameFlow 流程机、MENU 几何态、三屏)。
- **视觉占位 → `/role-art-spec`**:MENU 窗尺寸(占位 560×400)/三屏视觉/`[☰]` 图标位置/strip↔MENU 过渡/启动首帧
  贴底闪,均并入全局 UI·juice 一轮(见 CHANGES Wiring W7)。

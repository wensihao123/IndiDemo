---
artifact: PLAN
feature: 06-difficulty-progression
role: Planner
status: draft
updated: 2026-06-20
inputs: [project-context.md, ARCHITECTURE.md, BALANCE.md, balance/BALANCE-CHANGE-04-difficulty-progression.md, FEATURE-DESIGN.md, src/core/combat/progression_controller.gd, src/core/game_controller.gd, src/combat/combat_view.gd, assets/data/combat/stage_02.tres, test/core/combat/progression_test.gd, test/core/game_controller_test.gd]
next: Implementer
---

# PLAN — 06 难度推进:撞墙 → 变强 → 冲过(v1 闭环收口)

## 1. Goal
把"刷→调→再挑战"闭环真正闭上:**让关2 Boss 成为一堵玩家撞得到的墙**(num-smith 已定值),
**收口墙后的 v1 终点态**(打通末关不再掉进空场/越界续战),并给**卡关可读 / 回城邀请 / 突破庆祝**
三处最简占位呈现——全程复用现有进度骨架与内容,不造新系统。

## 2. Approach & key decisions

**总基调:** 06 是"收口件",代码面尽量小。墙 = 纯数据微调(num-smith 已拍);唯一的逻辑改动是
**末关边界收口**(修一个已存在的越界 bug);呈现一律最简占位(精修留全局 UI·juice 统一轮,守 memory
`defer_ui_until_features_done`)。

- **决策 A — 墙落关2 Boss,纯改 .tres 两字段(不碰公式/不加常量)。**
  - 什么:`assets/data/combat/stage_02.tres` 的 `BossOrcChieftain`:`max_hp 220→480`、`attack 9→24`(BALANCE-CHANGE-04)。
  - 为什么:num-smith 诊断"墙在数值上不存在"(关2 整条功率带在关1-通关玩家之下),双门槛(DPS+EHP)单点抬硬即成墙;数值走 Resource 配置,守 hard-NO。
  - 否决:抬整条关2 功率带做难度曲线 = 违 Producer LESS;改伤害公式 = 多余且动结构。(BALANCE-CHANGE-04 §6)

- **决策 B — 末关通关 = "终点关 Boss 循环陪伴",而非推进出界。** ⚠ 本功能唯一逻辑改动。
  - 什么:`ProgressionController.advance_after_wave()` 的 Boss 分支按"是否有下一关"分流:有下一关 → **维持现状**(`max_unlocked +1`、进 `STAGE_CLEAR_COUNTDOWN`、`advance_target=(beaten+1, 0)`);**无下一关(末关)→ 同样发 `boss_cleared`(供庆祝)、`max_unlocked +1`(语义/存档不变)、进 `STAGE_CLEAR_COUNTDOWN`,但 `advance_target` 指回 `(beaten_stage, BOSS_SCENE)`** → 倒计时到点 `_execute_push` 重刷末关 Boss = 终点安全循环(每刷一遍掉 ilvl30 = 支柱 1 陪伴 + 支柱 2 续供)。
  - 为什么:现状下打通末关后 `_execute_push` 把 `cur_stage` 推到 `stages.size()`(越界)→ `_spawn_current` 返回空波 → 玩家永远对着空场(`progression_controller.gd:58/87` + `:202-207` 实证)。FEATURE-DESIGN §3.3 边界态④要"打通终点的收尾反馈 + 之后在终点关安全刷陪伴",循环重刷末关 Boss 最简且兑现之。
  - **关键:`max_unlocked_stage = maxi(max_unlocked, beaten+1)` 的语义保持不动**——现有测试 `game_controller_test.gd:76/:92`、`progression_test.gd:98` 依赖"通末关 Boss → max_unlocked=beaten+1"(单关 `_quick_stages` 即末关场景)。改动只在 `advance_target`/`mode` 落点,不动解锁记账。
  - 否决:① 新增一个 `V1_CLEARED` FSM 终态 —— 加状态 = 动 FSM 骨架,06 守"不造新系统";循环复用 `STAGE_CLEAR_COUNTDOWN+_execute_push` 零新态。② 末关改去刷普通场景 —— 需新目标选择逻辑且掉落更差,不如重刷 Boss 简单且 loot 更好。

- **决策 C — 越界续战游标在 `begin_run` 夹回末关 Boss(补 #9 末关边界)。**
  - 什么:`ProgressionController.begin_run()` 开头加防呆:`if cur_stage >= stages.size(): cur_stage = max(0, size-1); cur_scene = BOSS_SCENE`(在 `max_unlocked` 行之前)。
  - 为什么:不变量 #9(`game_controller.gd:63-65`)在"末关 Boss 清算存档"(`cur_scene=BOSS` 且 `max_unlocked > cur_stage`)续战时会把 `_resume_stage` 设成 `max_unlocked_stage = 末关+1 = stages.size()`(越界)。`_boot` 处无 `stages` 无法夹;`begin_run` 持 `stages`,是唯一能夹的点。夹回 `(末关, BOSS)` = 与决策 B 的终点循环一致(续战即重刷末关 Boss)。
  - 否决:在 `_boot` 改 #9 判别 —— 那里拿不到 `stages.size()`,无法判越界;放 `begin_run` 才有上下文。

- **决策 D — 三处呈现走最简占位,挂 `combat_view.gd` 现有缝,纯只读不写战斗态。**
  - 什么:① **卡关可读**——复用 `_progress_text()` 的 GRINDING 分支(已读出"第N关·Boss·卡关刷怪"),最简补一行"打不过?"语义即可;② **回城邀请**——GRINDING 态显一行克制提示(如"装备不够?回城强化或许能过"),不弹窗、可无视;③ **突破庆祝**——`_on_boss_cleared(stage)` 判 `stage == 末关` → 比普通过关更重的占位庆祝(更大 `_flash` + 里程碑日志行),普通关维持现状。
  - 为什么:FEATURE-DESIGN §4 三处反馈意图;表现层只读 `ProgressionController.mode/cur_stage/cur_scene` + 演出,坐得住四层(ARCHITECTURE §3.3 表现层→战斗层只读),无需 arch-guard。正式皮/音/特效留统一轮。
  - 否决:加新 UI 系统/面板 —— FEATURE-DESIGN §6 明令"不加新 UI 系统",且 memory 定调占位先行。

## 3. Ordered steps

> 顺序:先把墙立起来(数据)→ 收口墙后终点态(逻辑)→ 再点亮呈现(表现)。每步可独立验证。

### 步 1 — 立墙:改关2 Boss 两字段(纯数据)
- **动作:** `assets/data/combat/stage_02.tres` 的 `BossOrcChieftain` sub-resource:`max_hp` 220→`480`、`attack` 9→`24`。其余字段(`item_level=30`、掉落权重、稀有度权重、display_name/sprite)**一律不动**;关2 三个普通场景、stage_01 **一律不动**。
- **文件:** `assets/data/combat/stage_02.tres`。
- **验证:** 新增纯逻辑用例(如 `test/core/combat/stage_wall_test.gd`):`load("res://assets/data/combat/stage_02.tres")` → 断言 `boss.max_hp == 480` 且 `boss.attack == 24`(锁住墙值,防静默回退)。若测内 .tres 资源加载不便,回退 = `godot --headless --check-only` 通过 + Inspector 肉眼核两字段。

### 步 2 — 收口末关边界(逻辑;决策 B + C)
- **动作 2a:** 改 `ProgressionController.advance_after_wave()` Boss 分支(`progression_controller.gd:127-136`)——按 `has_next := cur_stage + 1 < stages.size()` 分流:`has_next` 走现状;否则 `advance_target_stage = cur_stage`、`advance_target_scene = BOSS_SCENE`(其余:`boss_cleared.emit`、`max_unlocked = maxi(max_unlocked, cur_stage+1)`、`_revive_party()`、进 `STAGE_CLEAR_COUNTDOWN`、`countdown_remaining = _countdown_len()` 均**保持**)。
- **动作 2b:** 改 `ProgressionController.begin_run()`(`:43-52`)——在 `max_unlocked_stage = maxi(...)` 之前插防呆:`if cur_stage >= stages.size() and not stages.is_empty(): cur_stage = stages.size() - 1; cur_scene = BOSS_SCENE`。
- **文件:** `src/core/combat/progression_controller.gd`。
- **验证:**
  - 新增用例 `test/core/combat/progression_test.gd`:① **单关(末关)通 Boss → 倒计时到点 → 重刷末关 Boss**:`cur_stage` 仍 == 0、`cur_scene == BOSS_SCENE`、`current_enemy_def() != null`(非空场/不越界),且 `max_unlocked_stage == 1`(语义不变)。② **末关 Boss 清算存档续战不越界**:模拟 `begin_run(stages, stages.size(), 0)` → 夹回 `(size-1, BOSS_SCENE)`、`current_enemy_def() != null`。
  - **回归:** 现有 `progression_test`/`game_controller_test`/`save_system_test`/`retreat_test` 全绿——尤其 `:76/:92/:98`(末关 max_unlocked=1)、`test_boss_kill_unlocks_next_stage_permanently`(多关推进不受影响,因 `has_next=true` 走现状)、`test_reboot_after_boss_resumes_past_boss_not_refight`(关0→关1 续战,非末关)。
  - `godot --headless --check-only` 通过。

### 步 3 — 三处占位呈现(表现;决策 D)
- **动作:** 改 `combat_view.gd`:① GRINDING 态在进度读出旁显克制的"回城邀请"提示行(只读 `_prog.mode == GRINDING` 控显隐,不弹窗);② `_progress_text()` GRINDING 分支文案让"卡在某档墙"一眼可读(微调,不改结构);③ `_on_boss_cleared(stage)`(`:267-269`)判 `stage == _prog.stages.size() - 1` → 走更重的占位庆祝(放大版 `_flash` + "🏆 打通 v1 全部内容!" 里程碑日志);非末关维持"👑 通关第N关"。
- **文件:** `src/combat/combat_view.gd`(纯表现层,只读 progression;不新增数据结构、不写战斗态)。
- **验证:** **手动 Play**(表现层无单元测试):把 stage_01/stage_02 拖入 `CombatView.stages` 按 Play —— 观察 (a) 关2 撞墙团灭后软退、GRINDING 态读出"卡关"+ 回城邀请提示可见且不打断;(b) 回城(TownView)强化/换装后点"推进"再战,变强后能过墙;(c) 打通关2 Boss 触发比普通过关更重的庆祝,之后停在终点关循环刷 Boss(不空场)。无报错、无回归(掉落 FX / 团战渲染 / 面板照常)。

## 4. Out of scope
- **不建/改城镇** —— `TownView`(05)已落地验收(05 HANDOFF:accepted);06 仅复用其入口作"回城"动作。
- **不造难度机器** —— 难度曲线精调 / 动态难度 / 关3+ 新区域 / 新 Boss 机制 → v2(守 Producer LESS)。
- **不加新 UI 系统 / 不上正式皮·音·特效** —— 三处呈现一律占位;精修归全局 UI·juice 统一轮(memory `defer_ui_until_features_done`)。
- **不铺关2 团战多敌波**(08 deferred)—— 墙不依赖铺波,关2 维持单敌波;若未来铺且 `WAVE_SIZE>4` 才需抬 `combat_view.MAX_WAVE_SLOTS`(与本功能无关)。**[用户拍板 2026-06-20]** 06 先按本 PLAN 收口,关2 团战铺波**单列为 06 之后的独立后续任务**(structure 已在 08 落地:`SceneConfig.enemy_group` + `EnemyDef.position_class` + 近战 gate;待办 = 给 `stage_02.tres` 普通场景 author 多敌波,需 num-smith 定波规模/近远配比/相对数值)→ 建议 06 闭环后 `/role-producer` 记一条 backlog。
- **不做"变强后自动重试墙"** —— FEATURE-DESIGN 明确要玩家主动点推进(能动性);自动重试留后续可选。
- **不新增 `CombatTuning` 常量 / 不动数据结构** —— 墙是值微调,终点收口复用现有 FSM 态。

## 5. Risks & Flags / Open questions
- 🟡 **墙准度依赖词缀 roll 方差(债-3),最终由 playtest 主观裁定。** num-smith 校验(P1 过不去 / P2 能过)是期望值;运气差的 P2 可能压线、运气好的 P1-topped 可能勉强过。**调参旋钮:太松抬 Boss `attack`,太硬先降 `attack` 再降 `max_hp`(BALANCE-CHANGE-04 §6)。** 本期落值后交 playtest 观察,不预先再调。
- 🟡 **决策 B/C 触及不变量 #9 末关边界,请 Reviewer 重点核。** 改动只**补全** #9 未定义的"末关已通"边界(原越界),不改其"通关续战不重打 Boss"主语义、不动 `max_unlocked` 记账。若团队更想要一个独立 `V1_CLEARED` 终态(而非循环重刷末关 Boss),那是 v2 体量、需 `/arch-guard` —— 本期取最小循环方案。
- 🟡 **终点循环每刷一遍末关 Boss 都 `boss_cleared.emit` → 庆祝/autosave 重复触发。** 占位庆祝可接受重复("再次通关");若 playtest 嫌吵,表现层可加"仅首次里程碑"判重(留 UI·juice 轮,不进本期最小版)。
- 🟢 **关2 可达性前提:** 墙只在 `CombatView.stages` 含 stage_02 时可撞(编辑器拖入,数据走 Resource)。接线时确认 stage_01+stage_02 均在导出数组(现状已是)。
- 🟢 **无需新数据结构 / 无新依赖** —— 全用现有四层 + FSM,符合 ARCHITECTURE §5 扩展点与 hard-NO。

---
artifact: REVIEW
feature: 06-difficulty-progression
role: Reviewer
status: accepted
updated: 2026-06-20
inputs: [project-context.md, PLAN.md, CHANGES.md, FEATURE-DESIGN.md, src/core/combat/progression_controller.gd, src/core/game_controller.gd, src/combat/combat_view.gd, assets/data/combat/stage_02.tres, test/core/combat/progression_test.gd, test/combat/stage_config_test.gd, test/core/game_controller_test.gd, reports/report_38/results.xml]
next: Engine Integrator
---

# REVIEW — 06 难度推进:撞墙 → 变强 → 冲过(v1 闭环收口)

## 1. Verdict
**APPROVE WITH NITS**

代码逻辑面(本功能的难点 = 决策 B/C 对不变量 #9 末关边界的补全)是**对的、忠于计划的、且有测试锁住**。
HANDOFF 点名要我重点核的"末关 Boss 循环 vs 越界 / `begin_run` 夹值是否动了 `max_unlocked` 记账"——
两条都经手追完:**循环正确、记账语义零改动**。唯一值得动手的是表现层一处布局重叠(回城邀请行压住小队栏),
属占位精修范畴、归手动 Play + 全局 UI·juice 轮收口,不挡代码合入。

逐字核过 CHANGES「152/152 绿」非空口——`reports/report_38/results.xml`:`tests="152" failures="0"`,
其中 `progression_test` 9 例(原 7 + 决策 B/C 新 2)、`stage_config_test` 6 例(原 5 + 锁墙 1),全绿。

## 2. Must-fix (blocking)
无。

## 3. Should-fix (non-blocking)
- ~~**`src/combat/combat_view.gd:547`(回城邀请行布局)与小队栏重叠。**~~ **【2026-06-20 关闭 — 手动 Play 经手验:回城邀请行可见、不与小队栏冲突,"卡关可读"成功标准②达成。坐标担忧在实际游玩中不成立,无需改动。】**
  <details><summary>原始记录(已不适用)</summary>
  - 问题:`_retreat_invite_label` 落点 `(16, 36)`,文案长(约 24 字,font 12 → 宽 ~170px,横跨 x16→x186)。
    小队栏第 0 格战士:名字 Label 在 `(16, 38)`(`:434-435` `row_y=42-4`)、HP 底/条在 `x=86`(`:443/:453`)。
    GRINDING 态下回城邀请与小队名字同处 `(16, ~37)`、且长文压过战士 HP 条 —— 三者叠在一起。
  - 为什么要紧:FEATURE-DESIGN §5 成功标准②要"GRINDING 进度读出 + 下方回城邀请行**可见、余光可懂**";
    文字互相重叠正是"不可读"。这是本功能要兑现的体验点,不是单纯美观问题。
  - 建议方向:把邀请行下移到不与小队栏/进度读出冲突的安全带(如进度读出正下方、小队栏右侧空白,或 y 调到日志区 `_log_label` 上方 ~130 一带),手动 Play 时一并校准。坐标级改动,不动逻辑。
  </details>

- **末关续战全链路(`_boot` #9 → `begin_run` 夹回)缺一条 GameController 级集成测试。**
  - 问题:决策 C 的越界夹由 `progression_test.test_begin_run_clamps_out_of_bounds_resume_cursor` 单测覆盖(直接喂 `begin_run(stages, size, 0)`),
    但"打通**末关** Boss → 自动存档 → 重 boot → #9 把 `_resume_stage` 抬到越界 → `begin_run` 夹回末关 Boss"这条**真实存档往返链**没有端到端用例。
    现有 `game_controller_test.test_reboot_after_boss_resumes_past_boss_not_refight` 用的是**两关**档(beaten=关0,非末关,走 `has_next` 现状分支),恰好不经过夹值路径。
  - 为什么要紧:#9 是这次唯一改的不变量边界,真实链路无回归网 → 未来动 `_boot`/`begin_run` 任一端时,这条末关续战路径会静默失守。
  - 建议方向:加一条 `game_controller_test`:单关(末关)档 boot → 通 Boss(autosave)→ `_booted_gc(true)` 重 boot → `begin_run(_quick_stages())` → 断言 `cur_stage==0 && cur_scene==BOSS_SCENE && current_enemy_def()!=null`。逻辑已对,只是补网。

## 4. Nits (optional)
- `combat_view.gd:264-272` `_on_boss_cleared`:终点循环每刷一遍末关 Boss 都触发里程碑庆祝 + autosave —— CHANGES/PLAN 已就地标注并接受重复("再次通关"),代码注释也在位。无需本期动;若 playtest 嫌吵,留全局 UI·juice 轮加"仅首次"判重即可。记录在此仅为闭合。
- `progression_controller.gd:53` `begin_run` 把 `maxi(max_unlocked, stage)` 入参改读已夹后的 `cur_stage`(CHANGES §4 偏离 2):正向核过——无夹时 `cur_stage==stage` 等价,有夹时取末关序号更正确,且 #9 路径下 `max_unlocked` 本就 = size,`maxi` 不变。属决策 C 的必要附带,不扩范围,认可。

## 5. What I checked but found fine
- **决策 A 立墙(`stage_02.tres`)**:`BossOrcChieftain` `max_hp=480`、`attack=24`,与 BALANCE-CHANGE-04 拍值一致;其余字段(item_level=30、掉落/稀有度权重、display_name/sprite)、关2 三普通场景、stage_01 均未动。锁值用例 `stage_config_test.gd:39` 已防静默回退。数值走 Resource,守 hard-NO。✓
- **决策 B 末关循环(`progression_controller.gd:133-149`)**:`has_next := beaten+1 < stages.size()` 分流正确——有下一关走现状 `(beaten+1, 0)`;末关 `advance_target=(beaten, BOSS_SCENE)`,倒计时到点 `_execute_push` 重刷末关 Boss = `current_enemy_def()!=null`,不越界、不空场。`boss_cleared.emit`/`max_unlocked=maxi(..,beaten+1)`/`_revive_party`/`mode=COUNTDOWN`/`countdown_remaining` 均保持。✓
- **决策 C 越界夹(`begin_run :50-52`)**:`cur_stage>=size and not empty → (size-1, BOSS_SCENE)`,夹在 `max_unlocked` 行之前;`stages` 是唯一能判越界的上下文(`_boot` 处无 `stages`,注释已说明)。✓
- **不变量 #9 记账语义零改动**:`max_unlocked = maxi(max_unlocked, beaten+1)` 与 `game_controller.gd:63-65` 的 #9 判别均未触动主语义;现有依赖 `:76/:92/:98`(末关 max_unlocked=1)、`test_reboot_after_boss_resumes_past_boss_not_refight`(两关续战不重打 Boss,走 has_next 现状分支不受影响)在 report_38 全绿。✓
- **决策 D 表现层坐得住四层**:`combat_view.gd` 三处改动只读 `_prog.mode/cur_stage/cur_scene/stages.size()` + 演出,不写战斗态、不新增数据结构/`@export`/autoload/信号(Wiring Contract「无新接线」核实属实);`_milestone_flash` 用独立 overlay 挂 `_fx_layer`,不复用 `_flash`,无残留。✓
- **回归与编译**:report_38 = 152 tests / 0 failures / 0 errors / 0 skipped;CHANGES 的 `--check-only EXIT=0` 与之自洽。✓
- **安全 / 过度设计**:本作单机无输入/网络面,无注入/authz/secret 风险;无新抽象、无新依赖、无新插件,复用现有 FSM 终点循环未加 `V1_CLEARED` 新态,守 LESS。✓

> ⚠ 我未在本机重跑 gdUnit4(`runtest.cmd` 不在仓库根、godot 未在 PATH);改以**核 `reports/report_38/results.xml`** 验证 CHANGES 的「152/152」声明属实。决策 B/C 的正确性以逐行代码追踪 + 新增 2 条单测断言交叉确认。

---
artifact: CHANGES
feature: 06-difficulty-progression
role: Implementer
status: draft
updated: 2026-06-20
inputs: [PLAN.md, balance/BALANCE-CHANGE-04-difficulty-progression.md, project-context.md, src/core/combat/progression_controller.gd, src/core/game_controller.gd, src/combat/combat_view.gd, assets/data/combat/stage_02.tres, test/combat/stage_config_test.gd, test/core/combat/progression_test.gd, test/core/game_controller_test.gd]
next: Reviewer
---

# CHANGES — 06 难度推进:撞墙 → 变强 → 冲过(v1 闭环收口)

## 1. What changed(每文件一行)
- `assets/data/combat/stage_02.tres` — `BossOrcChieftain`:`max_hp 220→480`、`attack 9→24`(立墙;其余字段全不动)。
- `test/combat/stage_config_test.gd` — 新增 `test_stage_02_boss_is_the_wall`,锁住关2 Boss hp480/atk24(防静默回退)。
- `src/core/combat/progression_controller.gd` — `advance_after_wave()` Boss 分支按"有无下一关"分流(末关 → `advance_target` 指回本关 Boss 循环);`begin_run()` 加越界游标夹回末关 Boss。
- `test/core/combat/progression_test.gd` — 新增 `test_last_stage_boss_loops_instead_of_advancing_out_of_bounds`、`test_begin_run_clamps_out_of_bounds_resume_cursor`。
- `src/combat/combat_view.gd` — 加 `_retreat_invite_label`(GRINDING 态回城邀请)、GRINDING 进度文案改为卡关可读、`_on_boss_cleared` 末关分流 + 新增 `_milestone_flash()` 终点里程碑占位庆祝。

## 2. Why(映射 PLAN 步号 / 决策)
- **步 1(决策 A)**:墙在数值上不存在(BALANCE-CHANGE-04 诊断 = 关2 功率带坐在关1-通关玩家之下)。单点抬关2 Boss 两维(hp=EHP 门槛、atk=DPS 门槛)即成双门槛墙,纯走 Resource 配置(守 hard-NO),不碰公式/不加常量。锁值用例防回退。
- **步 2(决策 B + C)**:06 是 v1 收口件,暴露两个既存越界 bug——① 打通末关 Boss 后 `_execute_push` 把 `cur_stage` 推到 `stages.size()`(越界)→ 空场;② 不变量 #9(`game_controller.gd:63-65`)在末关 Boss 清算存档续战时把游标设成越界 `max_unlocked_stage`。决策 B 让末关 Boss 通关后 `advance_target` 指回本关 Boss = 终点安全循环(FEATURE-DESIGN §3.3 边界态④),复用 `STAGE_CLEAR_COUNTDOWN+_execute_push` 不加新 FSM 态;决策 C 在 `begin_run`(唯一持 `stages` 的点)夹回末关 Boss。**`max_unlocked +1` 解锁记账语义保持不动**(现有测试 `:76/:92/:98` 依赖)。
- **步 3(决策 D)**:FEATURE-DESIGN §4 三处反馈意图——卡关可读 / 回城邀请 / 突破庆祝。纯表现层只读 `ProgressionController.mode/cur_stage/cur_scene`,不写战斗态、不加新 UI 系统(占位精修留全局 UI·juice 统一轮,守 memory `defer_ui_until_features_done`)。

## 3. How I verified it
- **步 1**:`runtest.cmd -a test/combat/stage_config_test.gd` → 6/6 PASSED(含 `test_stage_02_boss_is_the_wall`)。
- **步 2**:全量 gdUnit4 `runtest.cmd -a test` → **152/152 PASSED · 0 errors · 0 failures · 0 orphans**(含 2 条新末关边界用例;现有 `game_controller_test`/`progression_test`/`save_system_test`/`retreat_test` 全绿,关键 `:76/:92/:98` 末关 max_unlocked=1 不变、`test_reboot_after_boss_resumes_past_boss_not_refight` 多关续战不受影响)。
- **步 3**:`godot --headless --check-only --script res://src/combat/combat_view.gd` → EXIT=0、无 parse error;改后全量 gdUnit4 复跑仍 **152/152 PASSED**(确认新增 class 成员/方法不破坏全局编译)。
- ⚠ **手动 Play 未做(表现层,需人/Engine Integrator)**——见 Flags。

## 4. Deviations from the plan
- **步 1 锁值用例落点**:PLAN 建议新建 `test/core/combat/stage_wall_test.gd`,实际把 `test_stage_02_boss_is_the_wall` 加进**既有** `test/combat/stage_config_test.gd`(它本就是 .tres 数值的回归网,`load(STAGE_02)` 已验可用)。更符合现有约定、不增散落文件。锁的内容与 PLAN 等价(hp480/atk24)。
- **步 2 `begin_run` 夹值附带**:夹回末关时把 `max_unlocked_stage = maxi(max_unlocked_stage, stage)` 的入参 `stage` 改读已夹后的 `cur_stage`(否则会用越界的 `stage` 值)。无夹时 `cur_stage == stage`,行为等价;有夹时取末关序号,语义更正确。属决策 C 的必要附带,不扩范围。
- 其余无偏离。

## 5. Wiring Contract(给 Engine Integrator)
**本功能无新增需在引擎接线的脚本/节点/导出字段/信号**——三处改动均落在**已接线**的现有脚本内部:
- `stage_02.tres`:纯数据资源,Godot 自动重导入,无需接线。**前提(现状已满足)**:`CombatView.stages` 导出数组里须含 `stage_01.tres` + `stage_02.tres`(编辑器已拖入;墙只在含 stage_02 时可撞)。
- `combat_view.gd`:
  - `_retreat_invite_label`(新 Label)= **代码内建子节点**(`_build_ui` 里 `add_child`),非 inspector 字段,无需在编辑器配置。
  - 末关里程碑庆祝复用**既有**信号连接 `_prog.boss_cleared.connect(_on_boss_cleared)`(`_ready` 内,已接);`_milestone_flash()` 用代码临时 overlay 挂 `_fx_layer`,无新节点引用。
  - 无新 `@export`、无新 autoload / input action / group / 信号。
- `progression_controller.gd`:纯逻辑(RefCounted),由 `GameController` 持有驱动,无接线变化。

→ Engine Integrator 侧**只需在 Godot 编辑器按 Play 做表现层验收**(见下 Flags 手动 Play 清单),无接线动作。

## 6. Flags / Open questions
- 🔴 **手动 Play 验收待人做(表现层无单元测试)。** 验收清单(对 FEATURE-DESIGN §5 成功标准):
  1. **撞墙软退**:进关2、撞 Boss 团灭 → 自动软退到更早场景、GRINDING 安全刷,进度不丢、装备照掉,无报错/无焦虑弹窗。
  2. **卡关可读**:GRINDING 态进度读出 "⛰ 第 2 关 · Boss · 卡住了 · 安全刷怪中" + 下方回城邀请行可见,余光可懂。
  3. **回城变强冲过**:回城(TownView)强化/换装变强 → 点「推进」再战 → 过墙(踏实非压线非空过)。
  4. **末关庆祝 + 终点循环**:打通关2 Boss 触发比普通过关更重的全屏闪 + "🏆 打通 v1 全部内容" 日志;之后**停在终点关循环刷 Boss、不掉空场**。
- 🟡 **墙准度依赖词缀 roll 方差,最终由 playtest 主观裁定**(BALANCE-CHANGE-04 §6)。调参旋钮:太松抬 Boss `attack`、太硬先降 `attack` 再降 `max_hp`。本期落值后交 playtest,不预先再调。
- 🟡 **决策 B/C 触及不变量 #9 末关边界,请 Reviewer 重点核**(PLAN §5):只**补全** #9 未定义的"末关已通"边界(原越界),不改"通关续战不重打 Boss"主语义、不动 `max_unlocked` 记账。新增 2 条用例已锁两条边界路径。
- 🟡 **终点循环每刷一遍末关 Boss 都 `boss_cleared.emit` → 庆祝/autosave 重复触发**。占位庆祝接受重复("再次通关");若 playtest 嫌吵,可加"仅首次里程碑"判重(留 UI·juice 轮,不进本期最小版)。代码注释已就地标注。
- 🟢 **关2 团战仍单敌波**(08 deferred,用户 2026-06-20 拍板单列后续任务)——本功能未触及,墙不依赖铺波。
